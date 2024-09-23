library(tidyverse)
library(lubridate)

remotes::install_github('flare-forecast/FLAREr@single-parameter')
remotes::install_github("rqthomas/GLM3r")
Sys.setenv('GLM_PATH'='GLM3r')

lake_directory <- here::here()
setwd(lake_directory)
forecast_site <- "fcre"
configure_run_file <- "configure_run.yml"
config_set_name <- "glm_flare_v3"

#' Source the R files in the repository
walk(list.files(file.path(lake_directory, "R"), full.names = TRUE), source)

Sys.setenv("AWS_DEFAULT_REGION" = "renc",
           "AWS_S3_ENDPOINT" = "osn.xsede.org",
           "USE_HTTPS" = TRUE)


config_obs <- yaml::read_yaml(file.path(lake_directory,'configuration',config_set_name,'observation_processing.yml'))
configure_run_file <- "configure_run.yml"
config <- FLAREr:::set_up_simulation(configure_run_file,lake_directory, config_set_name = config_set_name)

message("Beginning generate targets")

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

noaa_ready <- TRUE

while(noaa_ready){
  
  # Run FLARE
  output <- FLAREr:::run_flare(lake_directory = lake_directory,
                               configure_run_file = configure_run_file,
                               config_set_name = config_set_name)
  
  message("Scoring forecasts")
  forecast_s3 <- arrow::s3_bucket(bucket = config$s3$forecasts_parquet$bucket, endpoint_override = config$s3$forecasts_parquet$endpoint, anonymous = TRUE)
  forecast_df <- arrow::open_dataset(forecast_s3) |>
    dplyr::mutate(reference_date = lubridate::as_date(reference_date)) |>
    dplyr::filter(model_id == 'glm_flare_v3',
                  site_id == forecast_site,
                  reference_date == lubridate::as_datetime(config$run_config$forecast_start_datetime)) |>
    dplyr::collect()
  
  if(config$output_settings$evaluate_past & config$run_config$use_s3){
    #past_days <- lubridate::as_date(forecast_df$reference_datetime[1]) - lubridate::days(config$run_config$forecast_horizon)
    past_days <- lubridate::as_date(lubridate::as_date(config$run_config$forecast_start_datetime) - lubridate::days(config$run_config$forecast_horizon))
    
    #vars <- arrow_env_vars()
    past_s3 <- arrow::s3_bucket(bucket = config$s3$forecasts_parquet$bucket, endpoint_override = config$s3$forecasts_parquet$endpoint, anonymous = TRUE)
    past_forecasts <- arrow::open_dataset(past_s3) |>
      dplyr::mutate(reference_date = lubridate::as_date(reference_date)) |>
      dplyr::filter(model_id == 'glm_flare_v3',
                    site_id == forecast_site,
                    reference_date == past_days) |>
      dplyr::collect()
    #unset_arrow_vars(vars)
  }else{
    past_forecasts <- NULL
  }
  
  combined_forecasts <- dplyr::bind_rows(forecast_df, past_forecasts)
  
  targets_df <- read_csv(file.path(config$file_path$qaqc_data_directory,paste0(config$location$site_id, "-targets-insitu.csv")),show_col_types = FALSE)
  
  
  scoring <- generate_forecast_score_arrow(targets_df = targets_df,
                                           forecast_df = combined_forecasts, ## only works if dataframe returned from output
                                           use_s3 = TRUE,
                                           bucket = config$s3$scores$bucket,
                                           endpoint = config$s3$scores$endpoint,
                                           local_directory = './BVRE-forecast-code/scores/bvre',
                                           variable_types = c("state","parameter"))
  
  forecast_start_datetime <- lubridate::as_datetime(config$run_config$forecast_start_datetime) + lubridate::days(1)
  start_datetime <- lubridate::as_datetime(config$run_config$forecast_start_datetime) - lubridate::days(1)
  restart_file <- paste0(config$location$site_id,"-", (lubridate::as_date(forecast_start_datetime)- days(1)), "-",config$run_config$sim_name ,".nc")
  
  FLAREr:::update_run_config(lake_directory = lake_directory,
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
                             bucket = config$s3$restart$bucket,
                             endpoint = config$s3$restart$endpoint,
                             use_https = TRUE)
  RCurl::url.exists("https://hc-ping.com/8b5c849d-a5a6-4d44-980c-676472cf3c70", timeout = 5)
  
  noaa_ready <- FLAREr:::check_noaa_present_arrow(lake_directory,
                                              configure_run_file,
                                              config_set_name = config_set_name)
}
