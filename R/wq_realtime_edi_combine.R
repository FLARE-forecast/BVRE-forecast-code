wq_realtime_edi_combine <- function(realtime_file,
                             qaqc_file,
                             config,
                             offset_file){
  
  
  # realtime_file = L1 FILE STORED ON GITHUB
  # qaqc_file = EXISTING FILE STORED ON EDI
  #library(yaml)
  #config <- read_yaml(config_file)

  if(!is.na(realtime_file)){
  #if(realtime_file_exists == TRUE){
    #Different lakes are going to have to modify this for their temperature data format
    
    d1 <- read.csv(realtime_file, na.strings = 'NA', stringsAsFactors = FALSE)
    #d1 <- realtime_file
    
    if(!is.na(qaqc_file)){
    #if(edi_exists == TRUE){
      d2 <- read.csv(qaqc_file, na.strings = 'NA', stringsAsFactors = FALSE)
      #d2 <- qaqc_file
      
      #subset d1 to only dates in d2
      #d1 <- d1_og[d1_og$DateTime %in% d2$DateTime,]
      #d2 <- d2[d2$DateTime %in% d1$DateTime,]
    }
    
    d1$DateTime <- lubridate::as_datetime(d1$DateTime,tz = "UTC")
    d1$TIMESTAMP <- lubridate::as_datetime(d1$DateTime,tz = "UTC") 
    
    d3 <-  data.frame(TIMESTAMP = d1$DateTime, 
                      wtr_1 = d1$ThermistorTemp_C_1, wtr_2 = d1$ThermistorTemp_C_2,
                      wtr_3 = d1$ThermistorTemp_C_3, wtr_4 = d1$ThermistorTemp_C_4,
                      wtr_5 = d1$ThermistorTemp_C_5, wtr_6 = d1$ThermistorTemp_C_6,
                      wtr_7 = d1$ThermistorTemp_C_7, wtr_8 = d1$ThermistorTemp_C_8,
                      wtr_9 = d1$ThermistorTemp_C_9, wtr_10 = d1$ThermistorTemp_C_10,
                      wtr_11 = d1$ThermistorTemp_C_11, wtr_12 = d1$ThermistorTemp_C_12,
                      wtr_13 = d1$ThermistorTemp_C_13, wtr_1_5_exo = d1$EXOTemp_C_1.5,
                      wtr_6_do = d1$RDOTemp_C_6, wtr_13_do = d1$RDOTemp_C_13,
                      Chla_1_5 = d1$EXOChla_ugL_1.5, doobs_1_5 = d1$EXODO_mgL_1.5,
                      doobs_6 = d1$RDO_mgL_6, doobs_13 = d1$RDO_mgL_13,
                      fDOM_1_5 = d1$EXOfDOM_QSU_1.5, bgapc_1_5 = d1$EXOBGAPC_ugL_1.5,
                      depth_1_5 = d1$EXODepth_m, Depth_m_13=d1$LvlDepth_m_13)
    
    if(!is.na(qaqc_file)){
    #if(edi_exists == TRUE){
      TIMESTAMP_in <- as_datetime(d1$DateTime,tz = "EST")
      d1$TIMESTAMP <- with_tz(TIMESTAMP_in,tz = "UTC")
      
      TIMESTAMP_in <- as_datetime(d2$DateTime,tz = "EST")
      d2$TIMESTAMP <- with_tz(TIMESTAMP_in,tz = "UTC")
      
      
      
      d4 <- data.frame(TIMESTAMP = d2$DateTime, 
                       wtr_1 = d2$ThermistorTemp_C_1, wtr_2 = d2$ThermistorTemp_C_2,
                       wtr_3 = d2$ThermistorTemp_C_3, wtr_4 = d2$ThermistorTemp_C_4,
                       wtr_5 = d2$ThermistorTemp_C_5, wtr_6 = d2$ThermistorTemp_C_6,
                       wtr_7 = d2$ThermistorTemp_C_7, wtr_8 = d2$ThermistorTemp_C_8,
                       wtr_9 = d2$ThermistorTemp_C_9, wtr_10 = d2$ThermistorTemp_C_10,
                       wtr_11 = d2$ThermistorTemp_C_11, wtr_12 = d2$ThermistorTemp_C_12,
                       wtr_13 = d2$ThermistorTemp_C_13, wtr_1_5_exo = d2$EXOTemp_C_1.5,
                       wtr_6_do = d2$RDOTemp_C_6, wtr_13_do = d2$RDOTemp_C_13,
                       Chla_1_5 = d2$EXOChla_ugL_1.5, doobs_1_5 = d2$EXODO_mgL_1.5,
                       doobs_6 = d2$RDO_mgL_6, doobs_13 = d2$RDO_mgL_13,
                       fDOM_1_5 = d2$EXOfDOM_QSU_1.5, bgapc_1_5 = d2$EXOBGAPC_ugL_1.5,
                       depth_1_5 = d2$EXODepth_m, Depth_m_13=d2$Depth_m_13)
      
      d <- rbind(d3,d4)
    } else{
      d <- d3
    }
    
  }else{
    #Different lakes are going to have to modify this for their temperature data format
    d1 <- bvrdata
    
    TIMESTAMP_in <- lubridate::as_datetime(d1$DateTime,tz = input_file_tz)
    d1$TIMESTAMP <- lubridate::with_tz(TIMESTAMP_in,tz = "UTC")
    
    d <-  data.frame(TIMESTAMP = d1$DateTime, 
                     wtr_1 = d1$ThermistorTemp_C_1, wtr_2 = d1$ThermistorTemp_C_2,
                     wtr_3 = d1$ThermistorTemp_C_3, wtr_4 = d1$ThermistorTemp_C_4,
                     wtr_5 = d1$ThermistorTemp_C_5, wtr_6 = d1$ThermistorTemp_C_6,
                     wtr_7 = d1$ThermistorTemp_C_7, wtr_8 = d1$ThermistorTemp_C_8,
                     wtr_9 = d1$ThermistorTemp_C_9, wtr_10 = d1$ThermistorTemp_C_10,
                     wtr_11 = d1$ThermistorTemp_C_11, wtr_12 = d1$ThermistorTemp_C_12,
                     wtr_13 = d1$ThermistorTemp_C_13, wtr_1_5_exo = d1$EXOTemp_C_1.5,
                     wtr_6_do = d1$RDOTemp_C_6, wtr_13_do = d1$RDOTemp_C_13,
                     Chla_1_5 = d1$EXOChla_ugL_1.5, doobs_1_5 = d1$EXODO_mgL_1.5,
                     doobs_6 = d1$RDO_mgL_6, doobs_13 = d1$RDO_mgL_13,
                     fDOM_1_5 = d1$EXOfDOM_QSU_1.5, bgapc_1_5 = d1$EXOBGAPC_ugL_1.5,
                     depth_1_5 = d1$EXODepth_m, Depth_m_13=d1$LvlDepth_m_13)
  }
  
  
  #d$fDOM_1_5 <- config$exo_sensor_2_grab_sample_fdom[1] + config$exo_sensor_2_grab_sample_fdom[2] * d$fDOM_1_5
  
  #oxygen unit conversion
  #d$doobs_1_5 <- d$doobs_1_5*1000/32  #mg/L (obs units) -> mmol/m3 (glm units)
  #d$doobs_6 <- d$doobs_6*1000/32  #mg/L (obs units) -> mmol/m3 (glm units)
  #d$doobs_13 <- d$doobs_13*1000/32  #mg/L (obs units) -> mmol/m3 (glm units)
  
  #d$Chla_1_5 <-  config$exo_sensor_2_ctd_chla[1] +  d$Chla_1_5 *  config$exo_sensor_2_ctd_chla[2]
  #d$doobs_1_5 <- config$exo_sensor_2_ctd_do_1_5[1]  +   d$doobs_1_5 * config$exo_sensor_2_ctd_do_1[2]
  #d$doobs_6 <- config$do_sensor_2_ctd_do_6[1] +   d$doobs_6 * config$do_sensor_2_ctd_do_6[2]
  #d$doobs_13 <- config$do_sensor_2_ctd_do_13[1] +   d$doobs_13 * config$do_sensor_2_ctd_do_13[2]
  
  ######################################################################################
  # END OF QAQC - now transform df from wide to long
  
  d <- d %>%
    dplyr::mutate(day = lubridate::day(TIMESTAMP),
                  year = lubridate::year(TIMESTAMP),
                  hour = lubridate::hour(TIMESTAMP),
                  month = lubridate::month(TIMESTAMP)) %>%
    dplyr::group_by(day, year, hour, month) %>%
    dplyr::select(-TIMESTAMP) %>%
    dplyr::summarise_all(mean, na.rm = TRUE) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(day = as.numeric(day),
                  hour = as.numeric(hour)) %>%
    dplyr::mutate(day = ifelse(as.numeric(day) < 10, paste0("0",day),day),
                  hour = ifelse(as.numeric(hour) < 10, paste0("0",hour),hour)) %>%
    dplyr::mutate(timestamp = lubridate::as_datetime(paste0(year,"-",month,"-",day," ",hour,":00:00"),tz = "UTC")) %>%
    dplyr::arrange(timestamp)
  
  d_therm <- d %>%
    dplyr::select(timestamp, wtr_1, wtr_2, wtr_3, wtr_4, wtr_5, wtr_6, 
                  wtr_7,wtr_8, wtr_9, wtr_10, wtr_11, wtr_12, wtr_13, Depth_m_13) %>%
    dplyr::rename(
      "1.0" = wtr_1,
      "2.0" = wtr_2,
      "3.0" = wtr_3,
      "4.0" = wtr_4,
      "5.0" = wtr_5,
      "6.0" = wtr_6,
      "7.0" = wtr_7,
      "8.0" = wtr_8,
      "9.0" = wtr_9,
      "10.0" = wtr_10,
      "11.0" = wtr_11,
      "12.0" = wtr_12,
      "13.0" = wtr_13) %>%
    tidyr::pivot_longer(cols = -c(timestamp,Depth_m_13), names_to = "depth", values_to = "observed") %>%
    dplyr::mutate(variable = "temperature",
                  method = "thermistor",
                  observed = ifelse(is.nan(observed), NA, observed))
  
  d_do_temp <- d %>% 
    dplyr::select(timestamp, wtr_6_do, wtr_13_do, Depth_m_13) %>%
    dplyr::rename("6.0" = wtr_6_do,
                  "13.0" = wtr_13_do) %>%
    tidyr::pivot_longer(cols = -c(timestamp,Depth_m_13), names_to = "depth", values_to = "observed") %>%
    dplyr::mutate(variable = "temperature",
                  method = "do_sensor",
                  observed = ifelse(is.nan(observed), NA, observed))
  
  d_exo_temp <- d %>%
    dplyr::select(timestamp, wtr_1_5_exo, Depth_m_13) %>%
    dplyr::rename("1.5" = wtr_1_5_exo) %>%
    tidyr::pivot_longer(cols = -c(timestamp, Depth_m_13), names_to = "depth", values_to = "observed") %>%
    mutate(variable = "temperature",
           method = "exo_sensor",
           observed = ifelse(is.nan(observed), NA, observed))
  
  d_do_do <- d %>%
    dplyr::select(timestamp, doobs_6, doobs_13, Depth_m_13) %>%
    dplyr::rename("6.0" = doobs_6,
                  "13.0" = doobs_13) %>%
    tidyr::pivot_longer(cols = -c(timestamp, Depth_m_13), names_to = "depth", values_to = "observed") %>%
    mutate(variable = "oxygen",
           method = "do_sensor",
           observed = ifelse(is.nan(observed), NA, observed))
  
  d_exo_do <- d %>%
    dplyr::select(timestamp, doobs_1_5, Depth_m_13) %>%
    dplyr::rename("1.5" = doobs_1_5) %>%
    tidyr::pivot_longer(cols = -c(timestamp, Depth_m_13), names_to = "depth", values_to = "observed") %>%
    mutate(variable = "oxygen",
           method = "exo_sensor",
           observed = ifelse(is.nan(observed), NA, observed))
  
  d_exo_fdom <- d %>%
    dplyr::select(timestamp, fDOM_1_5, Depth_m_13) %>%
    dplyr::rename("1.5" = fDOM_1_5) %>%
    tidyr::pivot_longer(cols = -c(timestamp, Depth_m_13), names_to = "depth", values_to = "observed") %>%
    mutate(variable = "fdom",
           method = "exo_sensor",
           observed = ifelse(is.nan(observed), NA, observed))
  
  d_exo_chla <- d %>%
    dplyr::select(timestamp, Chla_1_5, Depth_m_13) %>%
    dplyr::rename("1.5" = Chla_1_5) %>%
    tidyr::pivot_longer(cols = -c(timestamp, Depth_m_13), names_to = "depth", values_to = "observed") %>%
    mutate(variable = "chla",
           method = "exo_sensor",
           observed = ifelse(is.nan(observed), NA, observed))
  
  d_exo_bgapc <- d %>%
    dplyr::select(timestamp, bgapc_1_5, Depth_m_13) %>%
    dplyr::rename("1.5" = bgapc_1_5) %>%
    tidyr::pivot_longer(cols = -c(timestamp, Depth_m_13), names_to = "depth", values_to = "observed") %>%
    mutate(variable = "bgapc",
           method = "exo_sensor",
           observed = ifelse(is.nan(observed), NA, observed))
  
  d <- rbind(d_therm,d_do_temp,d_exo_temp,d_do_do,d_exo_do,d_exo_fdom,
             d_exo_chla,d_exo_bgapc)
  
  d <- d %>% dplyr::mutate(depth = depth) 
  
  d <- d %>%
    dplyr::rename(time = timestamp)
  
  #drop NA rows and negative depths
  d <- d[!is.na(d$observed),]
  
  d <- d[d$depth >=0,]
  
  ######################################################################################
  #now read in the offset file and calculate depth for each sensor/position
  offsets <- readr::read_csv(offset_file, show_col_types = FALSE) %>% 
    dplyr::select(-Reservoir,-Site)
    #dplyr::select(-c(Reservoir,Site))
  
  #make depth numeric so it matches offset position col
  d$depth <- as.numeric(d$depth)
  
  #rename depth to position for left_join
  names(d)[3] <- "Position"
  
  #add in offsets to df
  bvr_depths <- dplyr::left_join(d, offsets)
  
  #load plotly for this section only 
  library(plyr)
  
  # The pressure sensor was moved to be in line with the bottom thermistor. The top two thermistors has slid closer to each other
  # and were re-secured about a meter a part from each other. Because of this we need to filter before 2021-04-05 13:20:00 EST
  # and after. The top two thermistors exact offset will have to be determined again when the water level is high enough again. 
  bvr_pre_05APR21=bvr_depths%>%
    dplyr::filter(time<="2021-04-05 13:20")%>%
    dplyr::mutate(Sensor_depth=Depth_m_13-Offset_before_05APR21)%>% #this gives you the depth of the thermistors from the surface
    dplyr::mutate(depth=round_any(Sensor_depth, 0.5))#Round to the nearest 0.5
  
  bvr_post_05APR21=bvr_depths%>%
    dplyr::filter(time>"2021-04-05 13:20")%>%
    dplyr::mutate(Sensor_depth=Depth_m_13-Offset_after_05APR21)%>% #this gives you the depth of the thermistor from the surface
    dplyr::mutate(depth=plyr::round_any(Sensor_depth, 0.5)) #Round to the nearest 0.5
  
  #unload plotly becuase it messes w/ dplyr
  detach("package:plyr", unload = TRUE)
  
  # combine the pre April 5th and the post April 5th. Drop if the values are NA. Drop if the sensor depth is NA because can't
  # figure out the depth of the sensors. This will give you a depth for each sensor reading. 
  bvr_by_depth=bvr_pre_05APR21%>%
    rbind(.,bvr_post_05APR21)%>%
    dplyr::filter(!is.na(observed))%>%
    dplyr::filter(!is.na(depth))%>%
    dplyr::select(-Offset_before_05APR21, -Offset_after_05APR21, -Distance_above_sediments, -Depth_m_13, -Sensor_depth, -Position)
  
  #drop NA rows and negative depths
  bvr_by_depth <- bvr_by_depth[!is.na(bvr_by_depth$observed),]
  
  bvr_by_depth <- bvr_by_depth[bvr_by_depth$depth >=0,]
  
  #rename 0 depth to be 0.1
  bvr_by_depth$depth[bvr_by_depth$depth == 0] <- 0.1
  
  # write to output file
  return(bvr_by_depth)
}
