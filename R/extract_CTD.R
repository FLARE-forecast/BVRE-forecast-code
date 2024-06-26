extract_CTD <- function(fname,
                        input_file_tz,
                        focal_depths,
                        config_obs){

  d_ctd <- read_csv(fname,
                col_types = list(
                  Reservoir = readr::col_character(),
                  Site = readr::col_character(),
                  Date = readr::col_datetime(format = ""),
                  Depth_m = readr::col_double(),
                  Temp_C = readr::col_double(),
                  DO_mgL = readr::col_double(),
                  DO_pSat = readr::col_double(),
                  Cond_uScm = readr::col_double(),
                  Spec_Cond_uScm = readr::col_double(),
                  Chla_ugL = readr::col_double(),
                  Turb_NTU = readr::col_double(),
                  pH = readr::col_double(),
                  ORP_mV = readr::col_double(),
                  PAR_umolm2s = readr::col_double(),
                  Desc_rate = readr::col_double(),
                  Flag_Temp = readr::col_integer(),
                  Flag_DO = readr::col_integer(),
                  Flag_Cond = readr::col_integer(),
                  Flag_SpecCond = readr::col_integer(),
                  Flag_Chla = readr::col_integer(),
                  Flag_Turb = readr::col_integer(),
                  Flag_pH = readr::col_integer(),
                  Flag_ORP = readr::col_integer(),
                  Flag_PAR = readr::col_integer(),
                  Flag_DescRate = readr::col_integer())) %>%
    dplyr::mutate(Date = force_tz(Date, tzone = input_file_tz)) %>%
    dplyr::filter(Reservoir == "BVR" & Site == "50") %>%
    dplyr::select(Date, Depth_m, Temp_C, DO_mgL, Chla_ugL) %>%
    dplyr::rename("timestamp" = Date,
           "depth" = Depth_m,
           "temperature" = Temp_C,
           "oxygen" = DO_mgL,
           "chla" = Chla_ugL) %>%
    dplyr::mutate(oxygen = oxygen * 1000/32,
           chla = config_obs$ctd_2_exo_sensor_chla[1] + config_obs$ctd_2_exo_sensor_chla[2] * chla,
           oxygen = config_obs$ctd_2_exo_sensor_do[1] + config_obs$ctd_2_exo_sensor_do[2] * oxygen) %>%
    tidyr::pivot_longer(cols = c("temperature", "oxygen", "chla"), names_to = "variable", values_to = "observed") %>%
    dplyr::mutate(method = "ctd") %>%
    dplyr::mutate(time = lubridate::as_datetime(timestamp, tz = "UTC")) %>%
    dplyr::select(time , depth, observed, variable, method) 
  
  #select every 0.5m
  d_ctd <- d_ctd %>%
    dplyr::mutate(rdepth = plyr::round_any(depth, 0.5)) %>% 
    dplyr::group_by(time, rdepth, variable) %>%
    dplyr::summarise(observed = mean(observed)) %>% 
    dplyr::mutate(method = "ctd") %>% 
    dplyr::rename(depth = rdepth) 
  
  #order columns
  d_ctd <- d_ctd[,c("time","depth","observed","variable","method")]
  
  #add hour to 2019 data
  #  d_ctd <- d_ctd %>% mutate(timestamp = as.POSIXct(strptime(timestamp,"%Y-%m-%d"),formt="%Y-%m-%d %H:%M:%S")) %>%
   #   mutate(timestamp =  as.POSIXct(paste(timestamp,"12:00:00"), format="%Y-%m-%d %H:%M:%S"))

  if(!is.na(focal_depths)){
    d_ctd <- d_ctd  %>% filter(depth %in% focal_depths)
  }

  return(d_ctd)
}

#plot 2019 temp and DO data
# obs_2019 <- d_ctd %>% filter(timestamp>="2019-08-01" & timestamp<= "2019-09-16") %>% filter(depth %in% c(1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,11.0))
# obs_2019$timestamp <- as.Date(obs_2019$timestamp)
# 
# ggplot(subset(obs_2019, variable=="temperature"),aes(timestamp,value, color=as.factor(depth))) +geom_line() + scale_x_date(date_labels = "%b %d", limits=c(as.Date("2019-08-01"),NA))
# ggplot(subset(obs_2020, variable=="temperature"),aes(date,value, color=as.factor(depth))) +geom_line() + scale_x_date(date_labels = "%b %d", limits=c(as.Date("2020-08-13"),NA)) #02_process_data.R
# 
# ggplot(subset(obs_2019, variable=="oxygen"& depth %in% c(1.0,4.0,8.0)),aes(timestamp,value, color=as.factor(depth))) +geom_line()
# ggplot(subset(obs_2020, variable=="oxygen"),aes(date,value, color=as.factor(depth))) +geom_line()
