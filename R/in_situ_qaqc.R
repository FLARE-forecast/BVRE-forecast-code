in_situ_qaqc <- function(insitu_obs_fname,
                         data_location,
                         maintenance_file,
                         ctd_fname,
                         nutrients_fname,
                         secchi_fname,
                         cleaned_insitu_file,
                         site_id,
                         config){

  print("QAQC BVR sensors")

  d <- wq_realtime_edi_combine(realtime_file = insitu_obs_fname[1],
                          qaqc_file = insitu_obs_fname[2],
                          offset_file = insitu_obs_fname[3],
                          config = config)

  if(exists("ctd_fname")){
    if(!is.na(ctd_fname)){
      print("QAQC CTD")
      d_ctd <- extract_CTD(fname = file.path(config$file_path$data_directory,config$ctd_fname),
                           input_file_tz = "EST",
                           focal_depths = config$focal_depths,
                           config = config)
      d <- rbind(d,d_ctd)
    }
  }


  if(exists("nutrients_fname")){
    if(!is.na(nutrients_fname)){
      print("QAQC Nutrients")
      d_nutrients <- extract_nutrients(fname = file.path(config$file_path$data_directory,config$nutrients_fname),
                                       input_file_tz = "EST",
                                       focal_depths = config$focal_depths)
      d <- rbind(d,d_nutrients)
    }
  }


  if(exists("ch4_fname")){
    if(!is.na(ch4_fname)){
      print("QAQC CH4")
      d_ch4 <- extract_ch4(fname = file.path(config$file_path$data_directory,config$ch4_fname),
                           input_file_tz = "EST",
                           focal_depths = config$focal_depths)
      d <- rbind(d,d_ch4)
    }
  }
  
  cuts <- tibble::tibble(cuts = as.integer(factor(config$depths_bins_top)),
                         depth = config$depths_bins_top)
  
  methods <- NULL
  for(i in 1:length(config$measurement_methods)){
    methods <- c(methods, paste(names(config$measurement_methods)[i], unlist(config$measurement_methods[[i]]), sep = "_"))
  }
  
  d_clean <- d |>
    dplyr::mutate(method = paste(variable, method, sep = "_")) |>
    dplyr::mutate(cuts = cut(depth, breaks = config$depths_bins_top, include.lowest = TRUE, right = FALSE, labels = FALSE)) |>
    dplyr::mutate(time = lubridate::as_date(time) + lubridate::hours(hour(time))) |>
    dplyr::filter(lubridate::hour(time) == 0) |>
    dplyr::filter(method %in% methods) |>
    dplyr::group_by(cuts, variable, time) |>
    dplyr::summarize(observed = mean(observed, na.rm = TRUE), .groups = "drop") |>
    dplyr::left_join(cuts) |>
    dplyr::select(time, depth, observed, variable) |>
    tidyr::drop_na(observed)  |> 
    dplyr::arrange(time)

  if(!is.na(secchi_fname)){
    
    d_secchi <- extract_secchi(fname = file.path(secchi_fname),
                               input_file_tz = "EST",
                               focal_depths = config$focal_depths)
    
    d_secchi <- d_secchi |>
      mutate(time = lubridate::as_datetime(lubridate::as_date(time)))
    
    
    d_clean <- rbind(d_clean,d_secchi)
  }
  

  d_clean$site_id <- "bvre"
  
  d_clean <- d_clean %>%
    rename(datetime = time,
           observation = observed) |>
    select(datetime, site_id, depth, observation, variable)
  
  d_clean$observation <- round(d_clean$observation, digits = 4)
  
  if(!dir.exists(dirname(cleaned_insitu_file))){
    dir.create(dirname(cleaned_insitu_file), recursive = TRUE)
  }
  
  readr::write_csv(d_clean, cleaned_insitu_file)
  return(cleaned_insitu_file)

}
       
