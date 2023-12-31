#
rm(list = ls())
#
library(tidyverse)
library(sf)
library(foreach)
library(doParallel)

detectCores(all.tests = FALSE, logical = TRUE)
cl <- makeCluster(6, outfile ="")
registerDoParallel(cl)

# parametros
d <- 10
b <- 1

source("rutinas/funciones/extpol/extpol_2.R") #Extiente polígonos disjuntos

load("intermedios/lista_parroquias.RData")

# Excluir parroquias ya extendidas
sizeReport <- function(path, patt = ".*", dironly = FALSE, level = Inf) {
  
  files <- data.frame(name = character(), size = numeric())
  
  
  walkDir <- function(path, level) {
    
    filesInDir <- list.files(path, recursive = FALSE)
    
    for (file in filesInDir) {
      
      fullPath <- file.path(path, file)
      
      if (dironly && !dir.exists(fullPath)) {
        next
      }
      
      if (dir.exists(fullPath) && level > 0) {
        walkDir(fullPath, level - 1)
      } else {
        
        if (!dir.exists(fullPath) && grepl(patt, file)) {
          files <<- rbind(files, data.frame(name = fullPath, size = file.size(fullPath)))
        }
      }
    }
  }
  
  
  walkDir(path, level)
  
  
  return(files)
}
x <- sizeReport(path = "C:/Mochrie/marco_upm") %>% 
  filter(substr(name, 68, 94) == "manzanas_extendidas_10.gpkg") %>% 
  mutate(parroquia = substr(name,61, 66))

index <- index[!index %in% x$parroquia]


# primer for de provincia
foreach(i=1:length(index),
        .packages = c("tidyverse", "sf"))%dopar%{
  if(file.exists(paste0("intermedios/01_preparacion_validacion/", 
                        substr(index[i], 1, 2), "/", index[i],"/manzana.gpkg"))){
    
  manzana <- read_sf(paste0("intermedios/01_preparacion_validacion/", 
                            substr(index[i], 1, 2), "/", index[i],"/manzana.gpkg")) %>% 
    select(man, id_parroquia)
  
  zona <- read_sf(paste0("intermedios/01_preparacion_validacion/", 
                         substr(index[i], 1, 2), "/", index[i] ,"/zona.gpkg")) %>% 
    filter(substr(zon, 7, 9) != "999") 
  

  index_zon <- unique(zona$zon)
  
  man_ext <- vector("list", 0)
  
  if(file.exists(paste0("intermedios/01_preparacion_validacion/", 
                        substr(index[i], 1, 2), "/", index[i],"/manzana.gpkg"))){
    rios <- read_sf(paste0("intermedios/01_preparacion_validacion/", 
                           substr(index[i], 1, 2), "/", index[i] ,"/rios.gpkg")) %>% 
      st_collection_extract(type="POLYGON") %>% 
      summarise()
    
    for(z in index_zon){
      perfil <- zona %>% 
        filter(zon == z) 
      
      poli <- manzana %>% filter(substr(man, 1, 9) == z)
      
      polext <- extpol(poli , 
                       perfil, id = "man", buf = b, densidad = d, lindero = rios) 
      
      man_ext[[z]] <- polext[[2]]
      
    }
  }else{
    for(z in index_zon){
      perfil <- zona %>% 
        filter(zon == z) 
      
      poli <- manzana %>% filter(substr(man, 1, 9) == z)
      
      polext <- extpol(poli , 
                       perfil, id = "man", buf = 2, densidad = 0.5) 
      
      man_ext[[z]] <- polext[[2]]
      
    }
  }
  
  save(man_ext, 
       file = paste0("intermedios/01_preparacion_validacion/", 
                     substr(index[i], 1, 2), "/", index[i] ,"/manzanas_extendidas_", d, ".RData"))
  
  man_ext <- do.call(rbind, man_ext)
  
  dir.create(paste0("productos/01_preparacion_validacion/", 
                    substr(index[i], 1, 2)), showWarnings = F)
  
  dir.create(paste0("productos/01_preparacion_validacion/", 
                    substr(index[i], 1, 2), "/", index[i]), showWarnings = F)
  
  write_sf(man_ext, paste0("productos/01_preparacion_validacion/", 
                           substr(index[i], 1, 2), "/", index[i] ,"/manzanas_extendidas_", d, ".gpkg"))
  }
          cat(sprintf("Parroquia extendida", index[i], "\n"))
}
stopCluster(cl)
