#NOTE:  This plot converts to local time zone


manager_plot <- function(file_name,
                         target_file,
                         focal_depths = c(1, 4, 7)){
  
  
  png_file_name <- paste0(tools::file_path_sans_ext(file_name),"_turnover.png")
  
  output <- FLAREr::combine_forecast_observations(file_name,
                                                  target_file,
                                                  extra_historical_days = 5)
  obs <- output$obs
  full_time_extended <- output$full_time_extended
  diagnostic_list <- output$diagnostic_list
  state_list <- output$state_list
  forecast <- output$forecast
  par_list <- output$par_list
  obs_list <- output$obs_list
  state_names <- output$state_names
  par_names <- output$par_names
  diagnostics_names <- output$diagnostics_names
  full_time <- output$full_time
  obs_long <- output$obs_long
  depths <- output$depths
  
  full_time_local <- lubridate::with_tz(full_time, tzone = "EST5EDT")
  full_time_local_extended <- lubridate::with_tz(full_time_extended, tzone = "EST5EDT")
  
  if(length(which(forecast == 1)) > 0){
    
    
    png(png_file_name,width = 12, height = 6,units = 'in',res=300)
    par(mfrow=c(1,2))
    
    #PLOT OF TURNOVER PROBABILITY
    turnover_index_1 <- which(depths == 1)
    turnover_index_2 <- which(depths == 7)
    
    temp <- state_list[["temp"]]
    
    
    forecast_start <- min(which(forecast == 1))
    forecast_end <- length(forecast)
    prob_zero <- rep(NA,length(seq(forecast_start,forecast_end,1)))
    
    if(length(which(forecast == 1)) == 16){
      
      if(length(which(forecast == 1)) > 0){
        for(i in forecast_start:forecast_end){
          prob_zero[i-(forecast_start - 1)] = 100*length(which(temp[i,turnover_index_1,] - temp[i,turnover_index_2,] < 1))/length((temp[i,1,]))
        }
        
        plot(full_time_local,rep(-99,length(full_time_local)),ylim=c(0,100),xlab = 'date',ylab = '% chance')
        title('Turnover forecast',cex.main=0.9)
        
        forecast_index <- max(which(forecast == 0))
        
        points(full_time_local[forecast_start:forecast_end],prob_zero,type='o',ylim=c(0,100), xlab = 'date',ylab = 'Probablity of turnover')
        axis(1, at=full_time_local - lubridate::hours(lubridate::hour(full_time_local[1])),las=2, cex.axis=0.7, tck=-0.01,labels=FALSE)
        abline(v = full_time_local[forecast_index])
        text(full_time_local[4],80,'future')
        
      }
      
      depth_colors <- tibble::tribble(
        ~color, ~depth,
        "firebrick4", 0.1,
        "firebrick1", 0.5,
        "firebrick1", 1.0,
        "DarkOrange1", 1.5,
        "DarkOrange1", 2.0,
        "gold", 2.5,
        "gold", 3.0,
        "greenyellow", 3.5,
        "greenyellow", 4.0,
        "medium sea green", 4.5,
        "medium sea green", 5.0,
        "sea green", 5.5,
        "sea green", 6.0,
        "DeepSkyBlue4", 6.5,
        "DeepSkyBlue4", 7.0,
        "blue2", 7.5,
        "blue2", 8.0)#,
        #"blue4", 9.0,
        #"#6600CC", 10.0,
        #"#000033", 11.0)
      
      full_time_local_plotting <-seq(full_time_local[1] - lubridate::days(5), max(full_time_local), by = "1 day")
      forecast_index <- which(full_time_local_plotting == full_time_local[which.max(forecast == 0)])
      
      plot(full_time_local_plotting,rep(-99,length(full_time_local_plotting)),ylim=c(-5,35),xlim = c(full_time_local_plotting[1] - lubridate::days(2), max(full_time_local_plotting)), xlab = 'date',ylab = expression(~degree~C))
      title(paste0('Water temperature forecast'),cex.main=0.9)
      tmp_day <- full_time_local[-1][1]
      axis(1, at=full_time_local - lubridate::hours(lubridate::hour(full_time_local[1])),las=2, cex.axis=0.7, tck=-0.01,labels=FALSE)
      depth_colors_index = 0
      for(i in 1:length(depths)){
        if(length(which(depths[i]  %in% depth_colors$depth)) >= 1 ){
          depth_colors_index <- which(depth_colors$depth == depths[i])
          points(full_time_local_plotting[1:forecast_index], obs[1:forecast_index,i,1],type='l',col=depth_colors$color[depth_colors_index],lwd=1.5)
          index <- which(focal_depths == depths[i])
          if(length(index) == 1){
            temp_means <- rep(NA, length(full_time_local))
            temp_upper <- rep(NA, length(full_time_local))
            temp_lower <- rep(NA, length(full_time_local))
            for(k in 2:length(temp_means)){
              temp_means[k] <- mean(temp[k,i,])
              temp_lower[k] <- quantile(temp[k,i,], 0.1)
              temp_upper[k] <- quantile(temp[k,i,], 0.9)
            }
            
            points(full_time_local, temp_means,type='l',lty='solid',col=depth_colors$color[depth_colors_index],lwd=1.5)
            points(full_time_local, temp_upper,type='l',lty='dotted',col=depth_colors$color[depth_colors_index],lwd=1.5)
            points(full_time_local, temp_lower,type='l',lty='dotted',col=depth_colors$color[depth_colors_index],lwd=1.5)
          }
        }
      }
      
      abline(v = full_time_local[which.max(forecast == 0)])
      text(full_time_local_plotting[forecast_index-2],30,'past')
      text(full_time_local[4],30.1,'future')
      
      legend("left",c("0.1m","1m", "2m", "3m", "4m", "5m", "6m", "7m","8m"),#, "9m", "10m","11"),
             text.col=c("firebrick4", "firebrick1", "DarkOrange1", "gold", "greenyellow", "medium sea green", "sea green",
                        "DeepSkyBlue4", "blue2"),#, "blue4", "#6600CC","#000033"), 
             cex=1, y.intersp=1, x.intersp=0.001, inset=c(0,0), xpd=T, bty='n')
      legend('topright', c('mean','confidence bounds'), lwd=1.5, lty=c('solid','dotted'),bty='n',cex = 1)
      
      mtext(paste0('Beaverdam Reservoir\n',lubridate::month(tmp_day),'/',lubridate::day(tmp_day),'/',lubridate::year(tmp_day)), side = 3, line = -2, outer = TRUE, font = 2)
      dev.off()
    }else{
      message("Forecast output did not have 16 forecast days.  Not generating manager plot")
      png_file_name <- NA
    }
    invisible(png_file_name)
  }else{
    invisible(NA)
  }
}
