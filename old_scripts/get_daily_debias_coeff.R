#' Convert NOAA forecasts to GLM format
#'
#' @param obs_met_file
#' @param out_dir
#' @param forecast_dirs
#' @param start_datetime
#' @param end_datetime
#' @param forecast_start_datetime
#' @param local_tzone
#' @param use_forecasted_met
#' @param spatial_downscale
#' @param spatial_downscale_coeff
#'
#' @return
#' @export
#'
#' @examples
get_daily_debias_coeff <- function(obs_met_file = NULL,
                                  out_dir,
                                  forecast_dirs = NULL,
                                  local_tzone,
                                  start_datetime_local,
                                  end_datetime_local,
                                  forecast_start_datetime_local,
                                  use_forecasted_met,
                                  plot = TRUE){
  
  if(is.null(obs_met_file) & is.null(forecast_dirs)){
    stop("missing files to convert")
  }
  
  start_datetime_UTC <- lubridate::with_tz(start_datetime_local, tzone = "UTC")
  end_datetime_UTC <- lubridate::with_tz(end_datetime_local, tzone = "UTC") - lubridate::hours(1)
  forecast_start_datetime_UTC <- lubridate::with_tz(forecast_start_datetime_local, tzone = "UTC")
  
  full_time_UTC <- seq(start_datetime_UTC, (end_datetime_UTC), by = "1 hour")
  if(use_forecasted_met){
    if(forecast_start_datetime_UTC > start_datetime_UTC){
      full_time_UTC_hist <- seq(start_datetime_UTC, forecast_start_datetime_UTC - lubridate::hours(1), by = "1 hour")
    }else{
      full_time_UTC_hist <- NULL
    }
  }else{
    full_time_UTC_hist <- seq(start_datetime_UTC, end_datetime_UTC, by = "1 hour")
  }
  cf_met_vars <- c("air_temperature",
                   "surface_downwelling_shortwave_flux_in_air",
                   "surface_downwelling_longwave_flux_in_air",
                   "relative_humidity",
                   "wind_speed",
                   "precipitation_flux")
  glm_met_vars <- c("AirTemp",
                    "ShortWave",
                    "LongWave",
                    "RelHum",
                    "WindSpeed",
                    "Rain")
  
  if(!is.null(obs_met_file) & !is.null(full_time_UTC_hist)){
    
    obs_met_nc <- ncdf4::nc_open(obs_met_file)
    
    obs_met_time <- ncdf4::ncvar_get(obs_met_nc, "time")
    
    origin <- stringr::str_sub(ncdf4::ncatt_get(obs_met_nc, "time")$units, 13, 28)
    
    origin <- lubridate::ymd_hm(origin)
    
    obs_met_time <- origin + lubridate::hours(obs_met_time)
    
    met <- tibble::tibble(time = obs_met_time)
    
    for(i in 1:length(cf_met_vars)){
      
      met <- cbind(met, ncdf4::ncvar_get(obs_met_nc, cf_met_vars[i]))
    }
    
    ncdf4::nc_close(obs_met_nc)
    
    names(met) <- c("time", glm_met_vars)
    
    met <- met %>%
      dplyr::filter(time %in% full_time_UTC)
    
    if(!(dplyr::last(full_time_UTC) %in% met$time)){
      historical_met_error <- TRUE
    }else{
      historical_met_error <- FALSE
    }
    
  }else{
    met <- NULL
    historical_met_error <- FALSE
    
  }
  
  
  if(!is.null(forecast_dirs)){
    
    forecast_files <- lapply(forecast_dirs, function(x) list.files(x, pattern = ".nc", full.names = TRUE))
    
    # forecast_files <- forecast_files[!stringr::str_detect(string = forecast_files, pattern = basename(obs_met_file))]
    
    nfiles <-   lapply(forecast_files, length)
    
  }else if(!is.null(met)){
    
    nfiles <-   1
  }
  
  
  out1 <- lapply(forecast_files, function(dir) {
     #dir = forecast_files[[16]]
    if(length(dir) == 0) {
      return(NA)
    }
    print(dir[[1]])
    out2 <- lapply(dir, function(file) {
       #file <- dir[[1]]
      ens <- dplyr::last(unlist(stringr::str_split(basename(file),"_")))
      ens <- stringr::str_sub(ens,1,5)
      noaa_met_nc <- ncdf4::nc_open(file)
      noaa_met_time <- ncdf4::ncvar_get(noaa_met_nc, "time")
      origin <- stringr::str_sub(ncdf4::ncatt_get(noaa_met_nc, "time")$units, 13, 28)
      origin <- lubridate::ymd_hm(origin)
      noaa_met_time <- origin + lubridate::hours(noaa_met_time)
      noaa_met <- tibble::tibble(time = noaa_met_time, date = as.Date(noaa_met_time))
      
      for(i in 1:length(cf_met_vars)){
        noaa_met <- cbind(noaa_met, ncdf4::ncvar_get(noaa_met_nc, cf_met_vars[i]))
      }
      
      ncdf4::nc_close(noaa_met_nc)
      names(noaa_met) <- c("time", "date", glm_met_vars)
      met2 <-  noaa_met %>% dplyr::group_by(date) %>% 
        # dplyr::mutate(AirTemp = AirTemp - 273.15) %>% 
        dplyr::summarise(dplyr::across(AirTemp:WindSpeed, mean))
      noaa_met <- noaa_met %>% dplyr::group_by(date) %>% 
        dplyr::summarise(Rain = sum(Rain)) %>% 
        dplyr::left_join(met2, ., by = "date") %>% 
        dplyr::filter(ShortWave > 50) %>% 
        dplyr::mutate(ens = ens, fc_day = 1:nrow(.)) 
      
        
      
      return(noaa_met)
      
    })
    
    sub_met2 <- met %>%
      dplyr::mutate(date = as.Date(time)) %>% 
      # dplyr::mutate(AirTemp = AirTemp - 273.15) %>% 
      dplyr::group_by(date) %>% 
      dplyr::summarise(dplyr::across(AirTemp:WindSpeed, mean))
    sub_met <- met %>%
      dplyr::mutate(date = as.Date(time)) %>%  
      dplyr::group_by(date) %>% 
      dplyr::summarise(Rain = sum(Rain)) %>% 
      dplyr::left_join(sub_met2, ., by = "date") %>% 
      dplyr::filter(ShortWave > 50) %>% 
      dplyr::filter(date %in% out2[[1]][["date"]])
    
    met_ens <- do.call("rbind", out2)
    
    df2 <- dplyr::left_join(met_ens, sub_met, by = "date", suffix = c("", "_obs"))
    return(df2)
    
  })
  
  # Remove lists where there is no forecast data
   out1 <- out1[!is.na(out1)]
  
  df2 <- do.call("rbind", out1) 

   #remove rows with no temp observations because for some reason there is noaa data but no obs
   df2 <- df2[!is.na(df2$AirTemp_obs),] 
   
  out3 <- lapply(2:7, function(x) {
    model <- lm(df2[[x]] ~ df2[[x + 8]])
    intercept <- model$coefficients[1]
    slope <- model$coefficients[2]
    res <- residuals(model)
    r2 <- summary(model)$r.squared
    df <- data.frame(intercept = intercept, slope = slope, sd_res = sd(res), r2 = r2)
  })
  
  names(out3) <- names(df2)[2:7]
  df <- do.call("rbind", out3)
  out_df <- as.data.frame(t(df))
  
  if(plot) {
    mod <- reshape2::melt(df2[, c(1:7, 9)], id.vars = c("date", "fc_day"))
    obs <- reshape2::melt(df2[, c(1, 10:ncol(df2))], id.vars = "date")
    obs$variable <- gsub("_obs", "", obs$variable)
    names(obs)[3] <- "obs"
    names(mod)[4] <- "mod"
    df$variable <- row.names(df)
    
    dat <- dplyr::left_join(obs, mod, by = c("date", "variable"))
    dat <- na.exclude(dat)
    c_pal <- colorRampPalette(RColorBrewer::brewer.pal(11, "Spectral"))
    if(nrow(dat) > 0) {
      message("Printing plot...")
      p <- ggplot(dat) +
        geom_abline(slope = 1, intercept = 0) +
        geom_abline(data = df, aes(slope = slope, intercept = intercept), linetype = "dashed",
                    color = "red") +
        scattermore::geom_scattermore(aes(obs, mod, color = factor(fc_day))) +
        scale_color_manual(values =  c_pal(16)) +
        facet_wrap(~variable, scales = "free") +
        theme_classic()
      print(p)
      message("Done!")
    }
  }
  
return(out_df)
}

#df2_average <- df2 %>% group_by(date) %>% summarise_all(mean, na.omit=T)
#
##visualize noaa vs obs met variables - 1 hr not debiased
#plot(df2_average$date, df2_average$AirTemp_obs, type="l", col="orange")
#lines(df2_average$date, df2_average$AirTemp, type="l")
#legend("bottomright", c("obs","noaa"), pch = '', lty = 1, bty='n', col = c("orange","black"))
#
#plot(df2_average$date, df2_average$LongWave_obs, type="l", col="red", ylim=c(216,400))
#lines(df2_average$date, df2_average$LongWave, type="l")
#legend("topleft", c("obs","noaa"), pch = '', lty = 1, bty='n', col = c("red","black"))
#
#plot(df2_average$date, df2_average$ShortWave_obs, type="l", col="dark blue")
#lines(df2_average$date, df2_average$ShortWave, type="l")
#legend("topleft", c("obs","noaa"), pch = '', lty = 1, bty='n', col = c("dark blue","black"))
#
#plot(df2_average$date, df2_average$WindSpeed_obs, type="l", col="dark green")
#lines(df2_average$date, df2_average$WindSpeed, type="l")
#legend("topright", c("obs","noaa"), pch = '', lty = 1, bty='n', col = c("dark green","black"))
#
#plot(df2_average$date, df2_average$Rain_obs, type="l", col="light blue")
#lines(df2_average$date, df2_average$Rain, type="l")
#legend("topright", c("obs","noaa"), pch = '', lty = 1, bty='n', col = c("light blue","black"))
#
#plot(df2_average$date, df2_average$RelHum_obs, type="l", col="purple", ylim=c(0.3,1))
#lines(df2_average$date, df2_average$RelHum, type="l")
#legend("topleft", c("obs","noaa"), pch = '', lty = 1, bty='n', col = c("purple","black"))
#
##obs vs met
#plot(df2_average$AirTemp_obs, df2_average$AirTemp_obs, type="p", col="orange",pch=20, cex=2.5, xlim=c(266,291),ylim=c(266,291))
#abline(0,1,lwd=3,lty="dashed")
#
#plot(df2_average$LongWave, df2_average$LongWave_obs, type="p", col="red",pch=20, cex=2.5, xlim=c(200,390),ylim=c(200,390))
#abline(0,1,lwd=3,lty="dashed")
#
#plot(df2_average$ShortWave, df2_average$ShortWave_obs, type="p", col="dark blue",pch=20, cex=2.5, xlim=c(50,270),ylim=c(50,270))
#abline(0,1,lwd=3,lty="dashed")
#
#plot(df2_average$WindSpeed, df2_average$WindSpeed_obs, type="p", col="dark green",pch=20, cex=2.5, xlim=c(1,6),ylim=c(1,6))
#abline(0,1,lwd=3,lty="dashed")
#
#plot(df2_average$Rain, df2_average$Rain_obs, type="p", col="light blue",pch=20, cex=2.5, xlim=c(0,0.009),ylim=c(0,0.009))
#abline(0,1,lwd=3,lty="dashed")
#
#plot(df2_average$RelHum, df2_average$RelHum_obs, type="p", col="purple",pch=20, cex=2.5, xlim=c(0.3,1),ylim=c(0.3,1))
#abline(0,1,lwd=3,lty="dashed")
#
#
##read in debiased noaa - randomly selecting ensemble 15
#noaa_debiased <- ncdf4::nc_open("/Users/heatherwander/Documents/VirginiaTech/research/BVR_GLM/BVRE-forecast/forecasted_drivers/NOAAGEFS_1hr/bvre/2021-03-15/00/NOAAGEFS_1hr_fcre_2021-03-15T00_2021-03-31T00_ens15.nc")
#temp <- ncdf4::ncvar_get(noaa_debiased,"air_temperature")
#long <- ncdf4::ncvar_get(noaa_debiased,"surface_downwelling_longwave_flux_in_air")
#short <- ncdf4::ncvar_get(noaa_debiased,"surface_downwelling_shortwave_flux_in_air")
#relhum<- ncdf4::ncvar_get(noaa_debiased,"relative_humidity")
#precip <- ncdf4::ncvar_get(noaa_debiased,"precipitation_flux")
#wind <- ncdf4::ncvar_get(noaa_debiased,"wind_speed")
#
##noaa 6 hr NOT debiased
#noaa_6hr <- ncdf4::nc_open("/Users/heatherwander/Documents/VirginiaTech/research/BVR_GLM/BVRE-forecast/forecasted_drivers/NOAAGEFS_6hr/bvre/2021-03-15/00/NOAAGEFS_6hr_fcre_2021-03-15T00_2021-03-31T00_ens15.nc")
#temp_6hr <- ncdf4::ncvar_get(noaa_6hr,"air_temperature")
#long_6hr <- ncdf4::ncvar_get(noaa_6hr,"surface_downwelling_longwave_flux_in_air")
#short_6hr <- ncdf4::ncvar_get(noaa_6hr,"surface_downwelling_shortwave_flux_in_air")
#relhum_6hr <- ncdf4::ncvar_get(noaa_6hr,"relative_humidity")
#precip_6hr <- ncdf4::ncvar_get(noaa_6hr,"precipitation_flux")
#wind_6hr <- ncdf4::ncvar_get(noaa_6hr,"wind_speed")
#
#
#dates=seq(as.POSIXct("2021-03-15 00:00:00"),max(as.POSIXct("2021-04-01")),by='1 hour')[1:385]
#dates<- as.Date(dates)
#
#dates_6hr <- seq(as.POSIXct("2021-03-15 00:00:00"),max(as.POSIXct("2021-04-01")),by='6 hour')[1:65]
#dates_6hr<- as.Date(dates_6hr)
#
##create df dor noaa debiased 1hr and noaa 6hr
#noaa_debiased <- data.frame(date=dates,temp=temp, longwave=long, shortwave=short, relhum=relhum, precip=precip,wind=wind) %>% 
#  group_by(date) %>% summarize(avg_temp=mean(temp),avg_longwave=mean(na.omit(longwave)),avg_shortwave=mean(na.omit(shortwave)),avg_relhum=mean(relhum),avg_precip=mean(na.omit(precip)),avg_wind=mean(wind))
#
#noaa_6hr <- data.frame(date=dates_6hr,temp=temp_6hr, longwave=long_6hr, shortwave=short_6hr, relhum=relhum_6hr, precip=precip_6hr, wind=wind_6hr) %>% 
#  group_by(date) %>% summarize(avg_temp=mean(temp),avg_longwave=mean(na.omit(longwave)),avg_shortwave=mean(na.omit(shortwave)),avg_relhum=mean(relhum),avg_precip=mean(na.omit(precip)),avg_wind=mean(wind))
#
#
##plotting observed vs noaa debiased 
#plot(df2_average$date[df2_average$date>="2021-03-15"], df2_average$AirTemp_obs[df2_average$date>="2021-03-15"], type="l",ylim=c(273,293), xlab="",ylab="temp_degreesC")
#lines(df2_average$date, df2_average$AirTemp, type="l", col="red") # 1hr not debiasaed 
#lines(noaa_debiased$date,noaa_debiased$avg_temp, type="l", col="dark orange") # 1 hr debiased
#lines(noaa_6hr$date,noaa_6hr$avg_temp, type="l", col="dark blue") # 6 hr not debiased
#legend("topleft", c("obs", "noaa_1hr", "noaa_1hr_debiased","noaa_6hr"), pch = '', lty = 1, bty='n', col = c("black","red","dark orange","dark blue"))
#
#plot(df2_average$date[df2_average$date>="2021-03-15"], df2_average$LongWave_obs[df2_average$date>="2021-03-15"], type="l",ylim=c(220,381), xlab="",ylab="longwave")
#lines(df2_average$date, df2_average$LongWave, type="l", col="red") # 1hr not debiasaed 
#lines(noaa_debiased$date,noaa_debiased$avg_longwave, type="l", col="dark orange") # 1 hr debiased
#lines(noaa_6hr$date,noaa_6hr$avg_longwave, type="l", col="dark blue") # 6 hr not debiased
#legend("topleft", c("obs", "noaa_1hr", "noaa_1hr_debiased","noaa_6hr"), pch = '', lty = 1, bty='n', col = c("black","red","dark orange","dark blue"))
#
#plot(df2_average$date[df2_average$date>="2021-03-15"], df2_average$ShortWave_obs[df2_average$date>="2021-03-15"], type="l", xlab="",ylab="shortwave")
#lines(df2_average$date, df2_average$ShortWave, type="l", col="red") # 1hr not debiasaed 
#lines(noaa_debiased$date,noaa_debiased$avg_shortwave, type="l", col="dark orange") # 1 hr debiased
#lines(noaa_6hr$date,noaa_6hr$avg_shortwave, type="l", col="dark blue") # 6 hr not debiased
#legend("topleft", c("obs", "noaa_1hr", "noaa_1hr_debiased","noaa_6hr"), pch = '', lty = 1, bty='n', col = c("black","red","dark orange","dark blue"))
#
#plot(df2_average$date[df2_average$date>="2021-03-15"], df2_average$Rain_obs[df2_average$date>="2021-03-15"], type="l", xlab="",ylab="shortwave")
#lines(df2_average$date, df2_average$Rain, type="l", col="red") # 1hr not debiasaed 
#lines(noaa_debiased$date,noaa_debiased$avg_precip, type="l", col="dark orange") # 1 hr debiased
#lines(noaa_6hr$date,noaa_6hr$avg_precip, type="l", col="dark blue") # 6 hr not debiased
#legend("topright", c("obs", "noaa_1hr", "noaa_1hr_debiased","noaa_6hr"), pch = '', lty = 1, bty='n', col = c("black","red","dark orange","dark blue"))
#
#plot(df2_average$date[df2_average$date>="2021-03-15"], df2_average$RelHum_obs[df2_average$date>="2021-03-15"], type="l", xlab="",ylab="shortwave",ylim=c(0,1))
#lines(df2_average$date, df2_average$RelHum, type="l", col="red") # 1hr not debiasaed 
#lines(noaa_debiased$date,noaa_debiased$avg_relhum, type="l", col="dark orange") # 1 hr debiased
#lines(noaa_6hr$date,noaa_6hr$avg_relhum, type="l", col="dark blue") # 6 hr not debiased
#legend("bottomright", c("obs", "noaa_1hr", "noaa_1hr_debiased","noaa_6hr"), pch = '', lty = 1, bty='n', col = c("black","red","dark orange","dark blue"))
