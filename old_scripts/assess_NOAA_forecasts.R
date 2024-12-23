# remotes::install_github("FLARE-forecast/GLM3r")
# remotes::install_github("FLARE-forecast/FLAREr")
# remotes::install_github("exaexa/scattermore")

#note - used 2020-12-01 - 2021-03-15 to create debiased noaa for 01-15mar 
#used 2020-12-01 - 2021-03-31 for debiased coefs for the 15-31mar debiased noaa data
#NOAA debiasing 
# 2020-12-01 to 2021-03-31 to get debias coeffs for bvr
#maybe try a shorter time period and calculate seasonal debias coeffs for each forecast horizon 
#then compare debiased NOAA vs met for different variables
#2020-09-24
#plot debiased in ncdf and make sure that downscaling worked - make sure coeffs aren't switched
#fcr 1 hr non-debiased forecast - do bvr and fcr matches
#lat long issue in the downloads?
#coeffs are applied at the daily scale so have to take daily means 
#are coeffs fit not on daily scale?

#oxygen only forecasts don't have other aed components so need to bump up sed params to represent phytos
#could just use noaa data insteead of met if can't get the noaa met comparison working

#inflows vs outflow could be off by a lot
#ox sat for a given temp 

#inflow vs no inflow and see if we get the jump
#if water level doesn't change then inflow isn't the issue
lake_directory <- getwd()
setwd(lake_directory)
forecast_location <- file.path(lake_directory, "configuration")

config <- yaml::read_yaml(file.path(forecast_location, "FLAREr","configure_flare.yml"))
run_config <- yaml::read_yaml(file.path(forecast_location, "FLAREr","configure_run.yml"))

# Set start & end dates 
run_config$start_day_local <- "2020-12-01" #"2021-03-01" 
run_config$end_day_local <- "2021-03-31" # "2020-09-09"
run_config$forecast_start_day_local <- "2021-03-15" # "2020-09-10"
run_config$start_time_local <- "00:00:00"

config$run_config$forecast_horizon <- 16

config$run_config <- run_config
config$run_config$forecast_location <- forecast_location

siteID <- "bvre"

# Set up timings
start_datetime_local <- lubridate::as_datetime(paste0(config$run_config$start_day_local," ",config$run_config$start_time_local), tz = "UTC")
if(is.na(config$run_config$forecast_start_day_local)){
  end_datetime_local <- lubridate::as_datetime(paste0(config$run_config$end_day_local," ",config$run_config$start_time_local), tz = "UTC")
  forecast_start_datetime_local <- end_datetime_local
}else{
  forecast_start_datetime_local <- lubridate::as_datetime(paste0(config$run_config$forecast_start_day_local," ",config$run_config$start_time_local), tz = "UTC")
  end_datetime_local <- forecast_start_datetime_local + lubridate::days(config$run_config$forecast_horizon)
}
spin_up_time <- seq(start_datetime_local, as.POSIXct(run_config$end_day_local), by = "1 day")
full_time_forecast <- seq(start_datetime_local, end_datetime_local, by = "1 day")

#Weather Drivers
start_datetime_UTC <-  lubridate::with_tz(start_datetime_local, tzone = "UTC")
end_datetime_UTC <-  lubridate::with_tz(end_datetime_local, tzone = "UTC")
forecast_start_datetime_UTC <- lubridate::with_tz(forecast_start_datetime_local, tzone = "UTC")
forecast_hour <- lubridate::hour(forecast_start_datetime_UTC)
if(forecast_hour < 10){forecast_hour <- paste0("0",forecast_hour)}
noaa_forecast_path <- file.path(getwd(),"forecasted_drivers","NOAAGEFS_1hr",siteID,lubridate::as_date(run_config$forecast_start_day_local),forecast_hour)
noaa_forecast_paths <- file.path(getwd(),"forecasted_drivers","NOAAGEFS_1hr",siteID,lubridate::as_date(full_time_forecast),forecast_hour)

debias_fc_path <- file.path(getwd(),"forecasted_drivers","NOAAGEFS_1hr",siteID,lubridate::as_date(spin_up_time),forecast_hour)

pacman::p_load(tidyverse, lubridate, noaaGEFSpoint, magrittr)

# Set up timings
 start_datetime_local <- lubridate::as_datetime(paste0(config$run_config$start_day_local," ",config$run_config$start_time_local), tz = "UTC")
 if(is.na(config$run_config$forecast_start_day_local)){
   end_datetime_local <- lubridate::as_datetime(paste0(config$run_config$end_day_local," ",config$run_config$start_time_local), tz = "UTC")
   forecast_start_datetime_local <- end_datetime_local
 }else{
   forecast_start_datetime_local <- lubridate::as_datetime(paste0(config$run_config$forecast_start_day_local," ",config$run_config$start_time_local), tz = "UTC")
   end_datetime_local <- forecast_start_datetime_local + lubridate::days(config$run_config$forecast_horizon)
 }

observed_met_file <- file.path(config$file_path$qaqc_data_directory,"observed-met_fcre.nc")

#Step up Drivers

#Weather Drivers
start_datetime_UTC <-  lubridate::with_tz(start_datetime_local, tzone = "UTC")
end_datetime_UTC <-  lubridate::with_tz(end_datetime_local, tzone = "UTC")
forecast_start_datetime_UTC <- lubridate::with_tz(forecast_start_datetime_local, tzone = "UTC")
forecast_hour <- lubridate::hour(forecast_start_datetime_UTC)
if(forecast_hour < 10){forecast_hour <- paste0("0",forecast_hour)}
forecast_path <- file.path(config$file_path$noaa_directory, config$location$site_id,lubridate::as_date(run_config$forecast_start_day_local),forecast_hour)

#downscale 
#all_files <- list.files("forecasted_drivers/NOAAGEFS_6hr", full.names = TRUE, recursive = TRUE)
#
#for(i in 1:length(all_files)){
#  print(i)
#  output_file <- stringr::str_replace_all(all_files[i], pattern = "6hr", replacement = "1hr")
#  noaaGEFSpoint::temporal_downscale(input_file = all_files[i], output_file = output_file)
#}

source("R/get_daily_debias_coeff.R")

# Returns a dataframe with intercept, slope, r2, sd_mod and plot of obs vs mod
#Sys.setenv("R_MAX_VSIZE" = 8e9) --> run if error: vector memory exhausted (limit reached?)
ds_coeff <- get_daily_debias_coeff(obs_met_file = observed_met_file,
                                 out_dir = config$run_config$execute_location,
                                 forecast_dirs = debias_fc_path,
                                 local_tzone = "UTC",
                                 start_datetime_local = start_datetime_UTC,
                                 end_datetime_local = end_datetime_UTC,
                                 forecast_start_datetime = forecast_start_datetime_UTC,
                                 use_forecasted_met = FALSE,
                                 plot = TRUE)
ds_coeff
#save(ds_coeff, file = "fcr2020.RData")

# Debias forecasts ----
# Create directory for
noaa_forecast_path <- file.path(lake_directory, "forecasted_drivers/NOAAGEFS_1hr/bvre/2021-03-15/00")
dir.create(file.path(noaa_forecast_path,"debiased"), showWarnings = FALSE)
fils <- list.files(noaa_forecast_paths[105], full.names = TRUE)[2:32]
dsd <- lapply(fils, function(i) {
  out_fnam <- file.path(lake_directory,"forecasted_drivers/NOAAGEFS_1hr/bvre/2021-03-15/00/debiased", gsub("NOAAGEFS", "NOAAGEFS-DEBIAS", basename(i))) 
  noaaGEFSpoint::debias_met_forecast(i, out_fnam,
                                     spatial_downscale_coeff = ds_coeff, overwrite = TRUE)
})

forecast_files <- list.files(noaa_forecast_path, full.names = TRUE)[2:32]

source("R/analyze_NOAA_forecast.R")

# Returns a plot of MAE for the forecast
p <- analyze_NOAA_forecast(obs_met_file = observed_met_file,
                           out_dir = config$run_config$execute_location,
                           forecast_dirs = noaa_forecast_path,
                           local_tzone = "UTC",
                           start_datetime_local = start_datetime_UTC,
                           end_datetime_local = end_datetime_UTC,
                           forecast_start_datetime = forecast_start_datetime_UTC,
                           use_forecasted_met = FALSE)
p
