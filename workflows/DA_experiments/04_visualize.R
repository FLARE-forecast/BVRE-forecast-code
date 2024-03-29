library(magrittr)
library(lubridate)

Sys.setenv("AWS_DEFAULT_REGION" = "s3",
           "AWS_S3_ENDPOINT" = "flare-forecast.org")

lake_directory <- here::here()

# configure_run_file <- "configure_run.yml"
# config_set_name <- "default"
# config <- FLAREr::set_configuration(configure_run_file,lake_directory, config_set_name = config_set_name)
# 
# config <- FLAREr::get_restart_file(config, lake_directory)

FLAREr::get_targets(lake_directory, config)

source(file.path(lake_directory,"R/plot_and_save.R")) #function that saves csv of all forecasted days (not just days w/ obs)

pdf_file <- plot_and_save(file_name = saved_file, #file.path(lake_directory, "forecasts","bvre","DA_experiments",names(date_list)[da_freq],config$run_config$restart_file),
                          target_file = file.path(lake_directory, "targets", config$location$site_id, paste0(config$location$site_id, "-targets-insitu.csv")),
                          obs_csv = TRUE) #FLAREr::plotting_general_2

#pdf_file <- FLAREr::plotting_general_2(file_name = config$run_config$restart_file,
#                                       target_file = file.path(lake_directory, "targets", config$location$site_id, paste0(config$location$site_id, "-targets-insitu.csv")))

if(config$run_config$use_s3){
  success <- aws.s3::put_object(file = pdf_file, object = file.path(config$location$site_id, basename(pdf_file)), bucket = "analysis")
  if(success){
    unlink(pdf_file)
  }
}

if(config$run_config$use_s3){
  unlink(file.path(config$file_path$qaqc_data_directory, paste0(config$location$site_id, "-targets-insitu.csv")))
  unlink(config$run_config$restart_file)
}
