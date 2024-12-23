#calculating flow for BVR using the Thornthwaite-mather water balance model
#modified to daily timestep - added in recharge to help with baseflow underestimation 11Jun2020
#Updated 4Sep2020 - change from GSOD temp/precip data to NLDAS for consistency 
#Updated 23Sep21 - change to obs met data because forecasts look weird when going from glm to FLARE
  
create_inflow_file <- function(realtime_file,
                        qaqc_file,
                        nldas_file){

lake_directory <- here::here()

#soil data
if(!file.exists(file.path(lake_directory,"configuration/DA_experiments/wss_aoi_2022-01-03_12-05-29"))){
  url <- "https://websoilsurvey.sc.egov.usda.gov/DSD/Download/AOI/kyhiens5ilrfk2x33jckqmbn/wss_aoi_2022-01-03_12-05-29.zip"
  download.file(url,file.path(lake_directory, "configuration", "DA_experiments", "wss_aoi_2022-01-03_12-05-29.zip"), method = "curl") #Note: will probably have to update wss_aoi date if it's been a while - go to wss homepage and click on start wss link on right of page
  unzip(file.path(lake_directory, "configuration", "DA_experiments", "wss_aoi_2022-01-03_12-05-29.zip"),
        exdir= file.path(lake_directory, "configuration", "DA_experiments"))            #zoom in to site, use define aoi tool to select desired area, go to download soils data tab, click "create download link", right click and copy link address, paste on url line above
}

#Using ROANOKE RIVER AT NIAGARA, VA  usgs gage to use as a template (will write over with BVR-specific data) 
myflowgage_id="02056000"
myflowgage=get_usgs_gage(myflowgage_id,begin_date = "2015-07-07",end_date = "2021-12-01")

#change coordinates and area for entire BVR watershed
myflowgage$area<- 2.27 #km
myflowgage$declat<- 37.31321
myflowgage$declon<- -79.81535

met <- read.csv(qaqc_file)

#want 2021 data too (even though it's not QAQC'ed)
met_realtime <- read.csv(realtime_file,header=T,skip=1)
met_realtime <- met_realtime[-c(1,2),-c(17)]

#drop first 3 rows because end of 1600 hour
met <- met[-c(1:3),-c(1,2)]

#change col names to match met
names(met_realtime) <- names(met)[1:17]

#add empty cols with same name as met df
met_realtime[,names(met)[18:43]] <- NA

#combine met datasets
met <- rbind(met,met_realtime)

#only select first entry for each hour
met_hourly <- met %>% select(c(DateTime,ShortwaveRadiationUp_Average_W_m2,InfraredRadiationUp_Average_W_m2,
                               AirTemp_Average_C,RH_percent,WindSpeed_Average_m_s,Rain_Total_mm)) %>% 
                      mutate(DateTime = ymd_hms(DateTime), dt = as_date(DateTime), hr = hour(DateTime)) %>% 
                      group_by(dt, hr) %>% filter(DateTime == min(DateTime)) %>% filter(DateTime <=as.Date("2019-12-31")) 
met_hourly_final <- met_hourly[,-c(8,9)]
names(met_hourly_final) <- c("time","ShortWave","LongWave","AirTemp","RelHum","WindSpeed","Rain")
#write.csv(met_hourly_final,"inputs/FCR_hourly_met_2015_2020.csv",row.names=FALSE)

#convert to as.date format
met$DateTime  <-as.Date(met$DateTime)

#convert air temp and rain cols to numeric
met$AirTemp_Average_C <- as.numeric(met$AirTemp_Average_C)
met$Rain_Total_mm <- as.numeric(met$Rain_Total_mm)

#then average by date
met_daily <- met %>% select(DateTime, AirTemp_Average_C, Rain_Total_mm) %>% group_by(DateTime) %>%
  rename(mdate=DateTime) %>% filter(mdate<=as.Date("2021-12-01")) %>%
  summarise(MaxTemp_C = max(AirTemp_Average_C, na.rm=T),
            MinTemp_C = min(AirTemp_Average_C, na.rm=T),
            MeanTemp_C = mean(AirTemp_Average_C, na.rm=T),
            Precip_mmpd = sum(Rain_Total_mm, na.rm=T)) 

#use NLDAS for missing met days
NLDAS<- read.csv(nldas_file)
NLDAS[is.na(NLDAS)]=0 # A Quick BUT sloppy removal of NAs

#convert NLDAS date to as.date format
NLDAS$time <-as.Date(NLDAS$time)
#convert rain from m/d to mm/hr 
NLDAS$precip_mm <-NLDAS$Rain * 1000 / 24

#average by date
NLDAS <- NLDAS %>% select(time, AirTemp, precip_mm) %>% group_by(time) %>%
  rename(mdate=time) %>%
  summarise(MaxTemp_C = max(AirTemp),
            MinTemp_C = min(AirTemp),
            MeanTemp_C = mean(AirTemp),
            Precip_mmpd = sum(precip_mm)) 

#new merged df with mostly met, but some NLDAS to fill missing days
dates <- seq(as.Date("2015-07-07"),as.Date("2021-12-01"),by="days")

#now fill in missing days with NLDAS
missing_met <- NLDAS[!(NLDAS$mdate %in% met_daily$mdate),] 
missing_met <- missing_met %>% filter(missing_met$mdate>=as.Date("2015-07-07"))
met_final <- rbind(missing_met,met_daily)

#replace flow with NAs because this is specific to Roanoke River (not BVR)
myflowgage$flowdata[["flow"]] <- NA

#only select days in both dataframes that match
myflowgage$flowdata <- myflowgage$flowdata[as.Date(myflowgage$flowdata$date) %in% met_final$mdate,]

# Merge met_final weather data with flow gage to use as our base HRU data structure
myflowgage$TMWB=merge(myflowgage$flowdata,met_final)

#set coordinates to plot DEM raster
degdist=sqrt(myflowgage$area*4)/80
mybbox = matrix(c(
  myflowgage$declon - degdist, myflowgage$declon + degdist, 
  myflowgage$declat - degdist, myflowgage$declat + degdist), 
  ncol = 2, byrow = TRUE)

if(!file.exists(file.path(lake_directory,"configuration/DA_experiments/soils"))){
mysoil <- mapunit_geom_by_ll_bbox(mybbox)
writeOGR(obj=mysoil, dsn="soils", layer="mysoil", driver="ESRI Shapefile")
}else(
mysoil <- readOGR(file.path(lake_directory,"configuration/DA_experiments/soils"))
)

# Associate mukey with cokey from component
mukey_statement = format_SQL_in_statement(unique(mysoil$mukey))
q_mu2co = paste("SELECT mukey,cokey FROM component WHERE mukey IN ", mukey_statement, sep="")
mu2co = SDA_query(q_mu2co)

# Second associate cokey with ksat_r,awc_r,hzdepb_r from chorizon
cokey_statement = format_SQL_in_statement(unique(mu2co$cokey))
q_co2ch = paste("SELECT cokey,ksat_r,awc_r,hzdepb_r  FROM chorizon WHERE cokey IN ", cokey_statement, sep="")
co2ch = SDA_query(q_co2ch)

# Aggregate max values of ksat_r,awc_r, and hzdepb_r
mu2ch=merge(mu2co,co2ch)
mu2chmax=aggregate(mu2ch,list(mu2ch$mukey),max)

# 3 Functions to calculate SWE and excess when soil is drying, wetting, and wetting above capacity
soildrying<-function(AWprev,dP,AWC){
  AW<-AWprev*exp(dP/AWC)
  excess<-0.0
  c(AW,excess)
}

soil_wetting_above_capacity<-function(AWprev,dP,AWC){
  AW<-AWC
  excess<-AWprev+dP-AWC
  c(AW,excess)
}

soilwetting<-function(AWprev,dP,AWC){
  AW<-AWprev+dP
  excess<-0.0
  c(AW,excess)
}

#initialize parameters
myflowgage$TMWB$AWC=0.13*400 #AWC=.13; 0.12 and 0.16 were the values obtained from USDA web soil survey
  # z=2000mm --> this one is hard because it really changes Qpred a LOT - calibrate this parameter? trees generally have <3500 mm roots...
myflowgage$TMWB$dP = 0 # Net precip
myflowgage$TMWB$ET = 0 # Evapotranspiration
myflowgage$TMWB$Albedo=.23
myflowgage$TMWB$PET = 0 # Potential evapotranspiration
myflowgage$TMWB$AW =  100 # Available water
myflowgage$TMWB$SnowMelt_mm = 0 
myflowgage$TMWB$SnowfallWatEq_mm = 0 # New snow
myflowgage$TMWB$SnowWaterEq_mm = 0  # Snow depth
myflowgage$TMWB$ExcessOut = 0 # Excess going out (runoff)
myflowgage$TMWB$Drainage = 0
myflowgage$TMWB$Qpred=NA
myflowgage$TMWB$Qpred[1]=0
myflowgage$TMWB$S=NA
myflowgage$TMWB$S[1]=0
myflowgage$fcres=0.3  #typically ranges from 0.2-0.5
myflowgage$SlopeRad=0.0 

TMWBModel<-function(hru_list){  
  # hru_list is the same object we have been using till now to store all our
  # variables and parameters.
  myflowgage=hru_list
  attach(myflowgage)
  attach(TMWB)
  
  # Snow accumulation and melt, as well as PET only depend on the surface attributes, and as such, can run  at the beginning, independent of the daily calculated ET, TMWB, and the linear reservoir Storage Discharge (Qmm). 
  SNO_Energy=SnowMelt(mdate, Precip_mmpd, MaxTemp_C-3, MinTemp_C-3, myflowgage$declat, 
                      slope = 0, aspect = 0, tempHt = 1, windHt = 2, groundAlbedo = 0.25,
                      SurfEmissiv = 0.95, windSp = 2, forest = 0, startingSnowDepth_m = 0,
                      startingSnowDensity_kg_m3=450)
  
  SnowMelt_mm=SNO_Energy$SnowMelt_mm     
  SnowWaterEq_mm=SNO_Energy$SnowWaterEq_mm 
  SnowfallWatEq_mm=SNO_Energy$SnowfallWatEq_mm
  myflowgage$TMWB$SnowMelt_mm=SnowMelt_mm
  myflowgage$TMWB$SnowWaterEq_mm=SnowWaterEq_mm
  myflowgage$TMWB$SnowfallWatEq_mm=SnowfallWatEq_mm
  myflowgage$TMWB$Albedo[myflowgage$TMWB$SnowfallWatEq_mm>0]=.95
  PET=PET_fromTemp(Jday=(1+as.POSIXlt(mdate)$yday),Tmax_C=MaxTemp_C,Tmin_C = MinTemp_C, lat_radians = myflowgage$declat*pi/180) * 1000
  myflowgage$TMWB$PET=PET
  
  # Those processes that are dependant on prior days conditions, we run as a loop through each of the days.
  for (t in 2:length(AW)){
    ET[t] = min (AW[t-1],PET[t]*AW[t-1]/AWC[t-1]) 
    # Calculating Net Precipitation 
    dP[t] = Precip_mmpd[t] - SnowfallWatEq_mm[t] - ET[t] + SnowMelt_mm[t]
    # TMWB Solution
    if (dP[t]<=0) {
      values<-soildrying(AW[t-1],dP[t],AWC[t])
    } else if((dP[t]>0) & (AW[t-1]+dP[t])<=AWC[t]) {
      values<-soilwetting(AW[t-1],dP[t],AWC[t])
    } else{
      values <- soil_wetting_above_capacity(AW[t-1],dP[t],AWC[t])
    }
    AW[t]<-values[1] 
    ExcessOut[t]<-values[2] #this is essentially just runoff 
    if(Precip_mmpd[t]>0) {Drainage[t]<- Precip_mmpd[t] - ExcessOut[t] - ET[t]} #recharge equation from Shuler and Mariner 2020
    if(Drainage[t]<0){ Drainage[t]<- 0}
    S[t]=S[t-1]+ExcessOut[t] + Drainage[t]
    Qpred[t]=fcres*S[t]  #Q as calculated from TMWB model (seems to underestimate baseflow without adding in recharge component)
    S[t]<-S[t]-Qpred[t] 
    print(t)
  }
  
  # UPDATE all the calculated vectors for list to be returned from function
  # BEFORE DETACHING
  myflowgage$TMWB$SnowMelt_mm=SnowMelt_mm
  myflowgage$TMWB$SnowWaterEq_mm=SnowWaterEq_mm
  myflowgage$TMWB$SnowfallWatEq_mm=SnowfallWatEq_mm
  myflowgage$TMWB$Albedo[myflowgage$TMWB$SNO>0]=.95
  myflowgage$TMWB$dP=dP
  myflowgage$TMWB$AW=AW
  myflowgage$TMWB$ExcessOut=ExcessOut
  myflowgage$TMWB$Drainage=Drainage
  myflowgage$TMWB$S=S
  myflowgage$TMWB$PET=PET
  myflowgage$TMWB$ET=ET
  myflowgage$TMWB$Qpred=Qpred 
  detach(TMWB)
  detach(myflowgage)
  # Return the updated list.
  return(myflowgage)
}

# Call the new TMWBModel() function 
TMWBsol=TMWBModel(myflowgage)
# Convert area from km to m (10^6) and Qpred from mm to m (10^-3) 
TMWBsol$TMWB$Qpred_m3pd=TMWBsol$TMWB$Qpred*TMWBsol$area*10^3
# Convert Qpred_m3pd to Qpred_m3ps (1m3/s = 86400 m3/d)
TMWBsol$TMWB$Qpred_m3ps=TMWBsol$TMWB$Qpred_m3pd/86400

#plots to visualize data
plot(TMWBsol$TMWB$mdate,TMWBsol$TMWB$Qpred_m3pd,col="red", type='l')
plot(TMWBsol$TMWB$mdate,TMWBsol$TMWB$Qpred_m3ps,col="orange", type='l')
plot(TMWBsol$TMWB$mdate,TMWBsol$TMWB$ExcessOut,col="blue", type='l')
plot(TMWBsol$TMWB$mdate,TMWBsol$TMWB$S,col="green", type='l')
plot(TMWBsol$TMWB$mdate,TMWBsol$TMWB$Drainage,col="purple", type='l')

#create csv for q export
QExport<- data.frame("time"=TMWBsol$TMWB$mdate, "Q_BVR_m3pd"=TMWBsol$TMWB$Qpred_m3pd)
write.csv(QExport, file.path(lake_directory, "data_processed/BVR_flow_calcs_obs_met_2015_2021.csv"))
}

