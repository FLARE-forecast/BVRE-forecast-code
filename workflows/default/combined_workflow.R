library(tidyverse)
library(lubridate)

lake_directory <- here::here()
setwd(lake_directory)
forecast_site <- "bvre"
configure_run_file <- "configure_run.yml"
config_set_name <- "default"

source("R/in_situ_qaqc.R")
source("R/temp_oxy_chla_qaqc.R")
source("R/extract_secchi.R")
source("R/run_edi_data_bind.R")


Sys.setenv("AWS_DEFAULT_REGION" = "renc",
           "AWS_S3_ENDPOINT" = "osn.xsede.org",
           "USE_HTTPS" = TRUE)

FLAREr::ignore_sigpipe()

noaa_ready <- TRUE

while(noaa_ready){
    
  message("Beginning generate targets")

  config_obs <- FLAREr::initialize_obs_processing(lake_directory, observation_yml = "observation_processing.yml", config_set_name = config_set_name)
  config <- FLAREr::set_configuration(configure_run_file,lake_directory, config_set_name = config_set_name)
  
  
  dir.create(file.path(lake_directory, "targets", config_obs$site_id), showWarnings = FALSE)

  FLAREr::get_git_repo(lake_directory,
                       directory = config_obs$realtime_insitu_location,
                       git_repo = "https://github.com/FLARE-forecast/BVRE-data.git")
  
  FLAREr::get_edi_file(edi_https = "https://pasta.lternet.edu/package/data/eml/edi/725/3/a9a7ff6fe8dc20f7a8f89447d4dc2038",
                       file = config_obs$insitu_obs_fname[2],
                       lake_directory)
  
  FLAREr::get_edi_file(edi_https = "https://pasta.lternet.edu/package/data/eml/edi/725/3/5927a50118644fa451badb3b84233bb7",
                       file = config_obs$insitu_obs_fname[3],
                       lake_directory)
  
  cleaned_insitu_file <- in_situ_qaqc(insitu_obs_fname = file.path(lake_directory,"data_raw", config_obs$insitu_obs_fname),
                                      data_location = file.path(lake_directory,"data_raw"),
                                      maintenance_file = file.path(lake_directory, "data_raw", config_obs$maintenance_file),
                                      ctd_fname = NA,
                                      nutrients_fname =  NA,
                                      secchi_fname = NA,
                                      cleaned_insitu_file = file.path(lake_directory,"targets", config_obs$site_id, paste0(config_obs$site_id,"-targets-insitu.csv")),
                                      site_id = config_obs$site_id,
                                      config = config_obs)
  
  FLAREr::put_targets(site_id = config_obs$site_id,
                      cleaned_insitu_file,
                      cleaned_met_file = NA,
                      cleaned_inflow_file = NA,
                      use_s3 = config$run_config$use_s3,
                      config = config)
  
  # Run FLARE
  output <- FLAREr::run_flare(lake_directory = lake_directory,
                              configure_run_file = configure_run_file,
                              config_set_name = config_set_name)
  
  
  forecast_start_datetime <- lubridate::as_datetime(config$run_config$forecast_start_datetime) + lubridate::days(1)
  start_datetime <- lubridate::as_datetime(config$run_config$forecast_start_datetime) - lubridate::days(1)
  restart_file <- paste0(config$location$site_id,"-", (lubridate::as_date(forecast_start_datetime)- days(1)), "-",config$run_config$sim_name ,".nc")
  
  FLAREr::update_run_config2(lake_directory = lake_directory,
                             configure_run_file = configure_run_file, 
                             restart_file = restart_file, 
                             start_datetime = start_datetime, 
                             end_datetime = NA, 
                             forecast_start_datetime = forecast_start_datetime,  
                             forecast_horizon = config$run_config$forecast_horizon,
                             sim_name = config$run_config$sim_name, 
                             site_id = config$location$site_id,
                             configure_flare = config$run_config$configure_flare, 
                             configure_obs = config$run_config$configure_obs, 
                             use_s3 = config$run_config$use_s3,
                             bucket = config$s3$warm_start$bucket,
                             endpoint = config$s3$warm_start$endpoint,
                             use_https = TRUE)
    
  RCurl::url.exists("https://hc-ping.com/8b5c849d-a5a6-4d44-980c-676472cf3c70", timeout = 5)
  
  noaa_ready <- FLAREr::check_noaa_present_arrow(lake_directory,
                                               configure_run_file,
                                               config_set_name = config_set_name)
}
