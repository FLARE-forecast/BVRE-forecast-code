forecast_inflows_outflows <- function(inflow_obs, 
                                      forecast_files, 
                                      obs_met_file, 
                                      output_dir, 
                                      inflow_model, 
                                      inflow_process_uncertainty, 
                                      config, 
                                      s3_mode = FALSE,
                                      bucket = NULL){

  inflow <- readr::read_csv(inflow_obs, col_types = readr::cols()) 
  
  #change tz from utc to est
  inflow$time <- with_tz(inflow$time, tzone = "EST")

  site_id <- config$location$site_id
  
  lake_directory <- getwd()

  curr_all_days <- NULL

  #CURRENTLY JUST PICKING 1 ENSEMBLE MEMBER
  noaa_met_nc <- ncdf4::nc_open(forecast_files[18]) 
  noaa_met_time <- ncdf4::ncvar_get(noaa_met_nc, "time")
  origin <- stringr::str_sub(ncdf4::ncatt_get(noaa_met_nc, "time")$units, 13, 28) 
  origin <- lubridate::ymd_hm(origin)  
  noaa_met_time <- origin + lubridate::hours(noaa_met_time)
  AirTemp_n <- ncdf4::ncvar_get(noaa_met_nc, "air_temperature")
  
  obs_met_nc <- ncdf4::nc_open(obs_met_file)
  obs_met_time <- ncdf4::ncvar_get(obs_met_nc, "time")
  origin <- stringr::str_sub(ncdf4::ncatt_get(obs_met_nc, "time")$units, 13, 28)
  origin <- lubridate::ymd_hm(origin)
  obs_met_time <- origin + lubridate::hours(obs_met_time)
  AirTemp <- ncdf4::ncvar_get(obs_met_nc, "air_temperature")
  Rain <- ncdf4::ncvar_get(obs_met_nc, "precipitation_flux")

  run_date <- lubridate::as_date(noaa_met_time[1])
  run_cycle <- lubridate::hour(noaa_met_time[1])
  if(run_cycle < 10){run_cycle <- paste0("0",run_cycle)}

  run_dir <- file.path(output_dir, inflow_model, site_id, run_date, run_cycle) 

  if(!dir.exists(run_dir)){
    dir.create(run_dir, recursive = TRUE)
  }

  ncdf4::nc_close(obs_met_nc)

  met <- tibble::tibble(time = obs_met_time,
                        AirTemp = AirTemp,
                        Rain = Rain)
  
  obs_met <- met %>% 
    dplyr::filter((time >= noaa_met_time[1] - lubridate::days(2)) & time < noaa_met_time[1])
   # dplyr::filter(time %in% noaa_met_time)

 # stacked_met <- ncdf4::nc_open(file.path(config$file_path$noaa_directory,"NOAAGEFS_1hr_stacked_average/bvre/observed-met-noaa_bvre.nc"))
 # obs_met_time <- ncdf4::ncvar_get(stacked_met, "time")
 # origin <- stringr::str_sub(ncdf4::ncatt_get(stacked_met, "time")$units, 13, 28)
 # origin <- lubridate::ymd_hm(origin)
 # obs_met_time <- origin + lubridate::hours(obs_met_time)
 # AirTemp <- ncdf4::ncvar_get(stacked_met, "air_temperature")
 # Rain <- ncdf4::ncvar_get(stacked_met, "precipitation_flux")
  
 # stacked_met <- tibble::tibble(time = obs_met_time,
 #                      AirTemp = AirTemp,
 #                      Rain = Rain)
  
  
  # met <- met %>% dplyr::filter(time>="2020-09-25" & time <= "2021-11-07") 
  #  
  # plot(stacked_met$AirTemp~stacked_met$time, type="l",col="dark red", ylim=c(255,310), xaxt = "n")
  # axis.POSIXct(1,stacked_met$time, at=seq(stacked_met$time[1],tail(stacked_met$time, n=1), "days"))
  # plot(met_2019$AirTemp~met_2019$time, type="l", col="darkblue", ylim=c(285,310), xaxt='n')
  # axis.POSIXct(1,met_2019$time, at=seq(met_2019$time[1],met_2019$time[1105], "days"))
  #
  # plot(stacked_met$Rain~stacked_met$time, type="l", col="dark red",xaxt = "n", ylim=c(0,0.008))
  # axis.POSIXct(1,stacked_met$time, at=seq(stacked_met$time[1],tail(stacked_met$time, n=1), "days"))
  # plot(met_2019$Rain~met_2019$time, type="l", col="dark blue", ylim=c(0,0.008), xaxt = "n")
  # axis.POSIXct(1,met_2019$time, at=seq(met_2019$time[1],met_2019$time[1105], "days"))

  
 #plot noaa vs obs met 
 # plot(noaa$Longwave~obs_met$Longwave, type="p", pch=16, col="darkred", xlim=c(270,470), ylim=c(270,470), ylab="noaa_longwave", xlab="met_longwave")
 # abline(0,1, lty=2)
 # plot(noaa$Shortwave~obs_met$Shortwave, type="p", pch=16, col="darkblue", xlim=c(0,1000), ylim=c(0,1000), ylab="noaa_shortwave", xlab="met_shortwave")
 # abline(0,1, lty=2)
 # plot(noaa$Wind~obs_met$Wind, type="p", pch=16, col="darkgreen", ylab="noaa_wind", xlab="met_wind")
 # abline(0,1, lty=2)
 # plot(noaa$AirTemp~obs_met$AirTemp, type="p", pch=16, col="Orange",  xlim=c(266,300), ylim=c(266,300),ylab="noaa_airtemp", xlab="met_airtemp")
 # abline(0,1, lty=2)

  init_flow_temp <- inflow %>%
    dplyr::filter(time == lubridate::as_date(noaa_met_time[1]) - lubridate::days(2))
  
#------------------------------------------------------------------------------#
#      Thornthwaite-Mather Water Balance Model for Forecasting Inflow          #
#------------------------------------------------------------------------------#      
  
  #soil data
  if(!file.exists(file.path(lake_directory,"configuration/default/wss_aoi_2022-01-03_12-05-29"))){
  url <- "https://websoilsurvey.sc.egov.usda.gov/DSD/Download/AOI/kyhiens5ilrfk2x33jckqmbn/wss_aoi_2022-01-03_12-05-29.zip"
  download.file(url,file.path(lake_directory, "configuration", "forecast_model", "t_m_water_balance", "wss_aoi_2022-01-03_12-05-29.zip"), method = "curl") #Note: will probably have to update wss_aoi date if it's been a while - go to wss homepage and click on start wss link on right of page
  unzip(file.path(lake_directory, "configuration", "default", "wss_aoi_2022-01-03_12-05-29.zip"),
                           exdir= file.path(lake_directory, "configuration", "default"))            #zoom in to site, use define aoi tool to select desired area, go to download soils data tab, click "create download link", right click and copy link address, paste on url line above
  }
  
  #Using ROANOKE RIVER AT NIAGARA, VA  usgs gage to use as a template (will write over with BVR-specific data) 
  myflowgage_id <- "02056000"
  myflowgage <- EcoHydRology::get_usgs_gage(myflowgage_id,begin_date = "2019-01-01",end_date = "2021-11-08") #change this!
  
  #only select dates during the forecast period
  myflowgage$flowdata <- myflowgage$flowdata[myflowgage$flowdata$mdate >= run_date-1 & myflowgage$flowdata$mdate <= run_date + 35,] 
  
  #change coordinates and area for entire BVR watershed
  myflowgage$area <- 2.27 #km
  myflowgage$declat <- 37.31321
  myflowgage$declon <- -79.81535
  
  #replace flow with NAs because this is specific to Roanoke River (not BVR)
  myflowgage$flowdata[["flow"]] <- NA
  
  #set coordinates to plot DEM raster
  degdist <- sqrt(myflowgage$area*4)/200
  mybbox <- matrix(c(
    myflowgage$declon - degdist, myflowgage$declon + degdist, 
    myflowgage$declat - degdist, myflowgage$declat + degdist), 
    ncol = 2, byrow = TRUE)
  
  if(!file.exists(file.path(lake_directory,"configuration/default/soils"))){
   mysoil <- mapunit_geom_by_ll_bbox(mybbox)
   writeOGR(obj=mysoil, dsn="soils", layer="mysoil", driver="ESRI Shapefile")
  }
  
  mysoil <- rgdal::readOGR(file.path(lake_directory, "configuration", "default","soils"))
  
  # Associate mukey with cokey from component
  mukey_statement <- soilDB::format_SQL_in_statement(unique(mysoil$mukey))
  q_mu2co <- paste("SELECT mukey,cokey FROM component WHERE mukey IN ", mukey_statement, sep="")
  mu2co <- soilDB::SDA_query(q_mu2co)
  
  # Second associate cokey with ksat_r,awc_r,hzdepb_r from chorizon
  cokey_statement <- soilDB::format_SQL_in_statement(unique(mu2co$cokey))
  q_co2ch <- paste("SELECT cokey,ksat_r,awc_r,hzdepb_r  FROM chorizon WHERE cokey IN ", cokey_statement, sep="")
  co2ch <- soilDB::SDA_query(q_co2ch)
  
  # Aggregate max values of ksat_r,awc_r, and hzdepb_r
  mu2ch <- merge(mu2co,co2ch)
  mu2chmax <- aggregate(mu2ch,list(mu2ch$mukey),max)
  
  # 3 Functions to calculate SWE and excess when soil is drying, wetting, and wetting above capacity
  soildrying <- function(AWprev, dP, AWC){
    AW <- AWprev*exp(dP/AWC)
    excess <- 0.0
    c(AW, excess)
  }
  
  soil_wetting_above_capacity <- function(AWprev, dP, AWC){
    AW <- AWC
    excess <- AWprev + dP - AWC
    c(AW, excess)
  }
  
  soilwetting <- function(AWprev, dP, AWC){
    AW <- AWprev + dP
    excess <- 0.0
    c(AW, excess)
  }
  
  for(j in 1:length(forecast_files)){

    ens <- dplyr::last(unlist(stringr::str_split(basename(forecast_files[j]),"_")))
    ens <- stringr::str_sub(ens,1,5)
    noaa_met_nc <- ncdf4::nc_open(forecast_files[j])
    noaa_met_time <- ncdf4::ncvar_get(noaa_met_nc, "time")
    origin <- stringr::str_sub(ncdf4::ncatt_get(noaa_met_nc, "time")$units, 13, 28)
    origin <- lubridate::ymd_hm(origin) 
    noaa_met_time <- origin + lubridate::hours(noaa_met_time)
    AirTemp <- ncdf4::ncvar_get(noaa_met_nc, "air_temperature")
    Rain <- ncdf4::ncvar_get(noaa_met_nc, "precipitation_flux")
    ncdf4::nc_close(noaa_met_nc)
    noaa_met <- tibble::tibble(time = noaa_met_time,
                               AirTemp = AirTemp,
                               Rain = Rain)

    noaa_met <- rbind(obs_met, noaa_met)
    
    curr_met_daily <- noaa_met %>%
      dplyr::mutate(AirTemp = AirTemp - 273.15,
                    Rain = Rain * (60 * 60 * 24)) %>% #was /1000 to get to m/d, but SnowMelt needs mm/d units
      dplyr::mutate(mdate = lubridate::as_date(time)) %>%
      dplyr::group_by(mdate) %>%
      dplyr::summarize(Rain = mean(Rain),
                       AirTemp = mean(AirTemp),
                       MaxTemp_C = max(AirTemp),
                       MinTemp_C = min(AirTemp),.groups = 'drop') %>%
      dplyr::mutate(ensemble = ens) %>%
      dplyr::mutate(AirTemp_lag1 = dplyr::lag(AirTemp, 1),
                    Rain_lag1 = dplyr::lag(Rain, 1),
                    MaxTemp_lag1 = dplyr::lag(MaxTemp_C, 1),
                    MinTemp_lag1 = dplyr::lag(MinTemp_C, 1)) %>%
      dplyr::slice(-1) %>%
      dplyr::mutate(FLOW = NA,
                    TEMP = NA)
    
    
    curr_met_daily$TEMP[1] <- init_flow_temp$TEMP

    if(inflow_process_uncertainty == TRUE){
      inflow_error <- rnorm(nrow(curr_met_daily), 0, config$future_inflow_flow_error)
      temp_error <- rnorm(nrow(curr_met_daily), 0, config$future_inflow_temp_error)
    }else{
      inflow_error <- rep(0.0, nrow(curr_met_daily))
      temp_error <- rep(0.0, nrow(curr_met_daily))
    }
      
      # Merge the NOAA weather data with flow gage to use as our base HRU data structure
      myflowgage$TMWB=merge(myflowgage$flowdata,curr_met_daily)
    
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
        SNO_Energy=SnowMelt(mdate, Rain_lag1, MaxTemp_lag1-3, MinTemp_lag1-3, myflowgage$declat, 
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
          dP[t] = Rain_lag1[t] - SnowfallWatEq_mm[t] - ET[t] + SnowMelt_mm[t]
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
          if(Rain_lag1[t]>0) {Drainage[t]<- Rain_lag1[t] - ExcessOut[t] - ET[t]} #recharge equation from Shuler and Mariner 2020
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
      
      # run the TMWBModel
      TMWBsol=TMWBModel(myflowgage)
      # Convert area from km to m (10^6) and Qpred from mm to m (10^-3) 
      TMWBsol$TMWB$Qpred_m3pd=TMWBsol$TMWB$Qpred*TMWBsol$area*10^3 #think about manually calibrating pars to get better inflow estimates
      # Convert Qpred_m3pd to Qpred_m3ps (1m3/s = 86400 m3/d)
      TMWBsol$TMWB$Qpred_m3ps=TMWBsol$TMWB$Qpred_m3pd/86400
            
      plot(TMWBsol$TMWB$mdate,TMWBsol$TMWB$Qpred_m3ps,col="red", type='l')

     #forecasted inflow
     # curr_met_daily$FLOW[1] <- 
      curr_met_daily$FLOW = TMWBsol$TMWB$Qpred_m3ps
     
     curr_met_daily$TEMP[1] <- curr_met_daily$AirTemp[1]  #pulled coeffs from nimble model in bvr_glm repo
     for(i in 2:nrow(curr_met_daily)){                                                  
       curr_met_daily$TEMP[i] = 0.07702 +
         0.80405 * curr_met_daily$AirTemp[i-1] +
         0.05872 * curr_met_daily$AirTemp_lag1[i] + 0.97773
     }
     
     #add in oxygen data from obs file
     #oxy <- read_csv(file.path(config$file_path$qaqc_data_directory,"observations_postQAQC_long.csv")) %>%
     #  dplyr::filter(depth==1, variable=="oxygen") %>% dplyr::filter(date %in% as.Date(noaa_met_time))

     #curr_met_daily$OXY_oxy <- oxy$value
     
     #change mdate col back to time
     curr_met_daily <- rename(curr_met_daily, time = mdate)
    
    curr_met_daily <- curr_met_daily %>%
      dplyr::mutate(FLOW = ifelse(FLOW < 0.0, 0.0, FLOW))

    curr_met_daily <- curr_met_daily %>%
      dplyr::mutate(SALT = 0.0) %>%
      dplyr::select(time, FLOW, TEMP, SALT, AirTemp, Rain) %>% #, OXY_oxy
      dplyr::mutate_at(dplyr::vars(c("FLOW", "TEMP", "SALT")), list(~round(., 4))) %>% #,"OXY_oxy"
      dplyr::mutate(type = "inflow",
                    inflow_num = 1) %>%
      slice(-1)

    #forecasting outflow - Schuler method using forecasted NOAA for precip and water level
    
    
    curr_met_daily_output <- curr_met_daily %>% #this assumes that outflow = inflow, but might want to think about this a bit
      dplyr::select(time, FLOW, TEMP) %>% #, OXY_oxy
      dplyr::mutate(type = "outflow",
                    outflow_num = 1)

    forecast_date <- run_date
    end_date <- dplyr::last(curr_met_daily$time)


    identifier_inflow <- paste0("INFLOW-FLOWS-NOAAGEFS-TMWB","_", site_id, "_", format(run_date, "%Y-%m-%d"),"_",
                                format(end_date, "%Y-%m-%d"))

    identifier_outflow <- paste0("OUTFLOW-FLOWS-NOAAGEFS-TMWB", "_", site_id, "_", format(run_date, "%Y-%m-%d"), "_",
                                 format(end_date, "%Y-%m-%d"))
    
    inflow_file_name <- file.path(run_dir, paste0(identifier_inflow,"_", ens, ".csv"))
    outflow_file_name <- file.path(run_dir, paste0(identifier_outflow,"_", ens, ".csv"))

    readr::write_csv(x = curr_met_daily,
                     file = inflow_file_name)

    readr::write_csv(x = curr_met_daily_output,
                     file = outflow_file_name)
    
     if(s3_mode){
      aws.s3::put_object(file = local_inflow_file_name,
                         object = file.path(run_dir, paste0(identifier_inflow,"_", ens, ".csv")),
                         bucket = bucket)
      aws.s3::put_object(file = local_outflow_file_name,
                         object = file.path(run_dir, paste0(identifier_outflow,"_", ens, ".csv")),
                         bucket = bucket)
    }

  }
  return(list(run_dir))
}

