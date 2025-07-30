# =============================================================================
# SCRIPT - CROP E MASK DE RASTERS COM VETORES
# =============================================================================
# Objetivo: Recortar e mascarar rasters (.tif) usando vetores (.gpkg) como 
# referência, aplicando operações de crop e mask para cada combinação
# =============================================================================

# 1. INSTALAR E CARREGAR BIBLIOTECAS NECESSÁRIAS
# =============================================================================
# Instalar as bibliotecas (necessário apenas uma vez)
# install.packages("terra")

# Carregar as bibliotecas
library(terra)

# Função para verificar se uma pasta existe e criar se necessário
check_and_create_folder <- function(folder_path) {
  if (!dir.exists(folder_path)) {
    dir.create(folder_path, recursive = TRUE)
    cat("Pasta criada:", folder_path, "\n")
  }
  return(dir.exists(folder_path))
}

# Função para verificar se há arquivos em uma pasta
check_files_exist <- function(folder_path, pattern) {
  files <- list.files(path = folder_path, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) {
    stop(paste("Nenhum arquivo", pattern, "encontrado em:", folder_path))
  }
  return(files)
}

# Caminhos para as pastas
bio_folder <- "C:/cropmask/camadas/"
vetores_folder <- "C:/cropmask/vetores/"
resultados_folder <- "C:/cropmask/resultados/"

# Verificar e criar pastas se necessário
cat("Verificando pastas...\n")
check_and_create_folder(bio_folder)
check_and_create_folder(vetores_folder)
check_and_create_folder(resultados_folder)

# Listar arquivos com verificação de existência
cat("Listando arquivos...\n")
bio_files <- check_files_exist(bio_folder, '\\.tif$')
vetores_files <- check_files_exist(vetores_folder, '\\.gpkg$')

cat("Rasters encontrados:", length(bio_files), "\n")
cat("Vetores encontrados:", length(vetores_files), "\n")

# Função para aplicar crop e mask em cada raster para cada vetor
process_raster <- function(raster_path, vetor_path) {
  # Carregar o raster
  cat("Processando:", basename(raster_path), "com", basename(vetor_path), "\n")
  r <- rast(raster_path)
  
  # Carregar o vetor e definir o CRS corretamente (ajuste conforme necessário)
  vetor <- vect(vetor_path)
  crs(vetor) <- "EPSG:4674"  # Defina o CRS correto para seus vetores
  
  # Aplicar o crop e o mask
  r_cropped <- crop(r, vetor)
  r_masked <- mask(r_cropped, vetor)
  
  # Verificar se o resultado não está vazio
  if (ncell(r_masked) == 0 || all(is.na(values(r_masked)))) {
    cat("Aviso: Resultado vazio para", basename(raster_path), "e", basename(vetor_path), "\n")
    return(NULL)
  }
  
  # Gerar nome para salvar o raster (adicionar o nome do vetor no sufixo do arquivo)
  output_path <- paste0("C:/cropmask/resultados/", 
                        basename(tools::file_path_sans_ext(raster_path)), 
                        "_", basename(tools::file_path_sans_ext(vetor_path)), 
                        "_masked.tif")
  
  # Salvar o raster resultante
  writeRaster(r_masked, output_path, overwrite = TRUE)
  cat("Arquivo salvo:", basename(output_path), "\n")
  
  return(r_masked)
}

# Loop principal com tratamento de erros
cat("Iniciando processamento...\n")
total_combinations <- length(bio_files) * length(vetores_files)
current_combination <- 0

for (vetor_file in vetores_files) {
  # Aplicar o processo para todos os rasters em cada vetor
  result_rasters <- lapply(bio_files, function(raster_file) {
    current_combination <<- current_combination + 1
    cat("Progresso:", current_combination, "/", total_combinations, "\n")
    return(process_raster(raster_file, vetor_file))
  })
  
  # Filtrar resultados nulos
  valid_results <- result_rasters[!sapply(result_rasters, is.null)]
  
  # Plotar o primeiro resultado válido se existir
  if (length(valid_results) > 0) {
    cat("Plotando primeiro resultado válido...\n")
    plot(valid_results[[1]], main = paste("Resultado para", basename(vetor_file)))
  }
}

cat("Processamento concluído!\n")
cat("Arquivos salvos em:", resultados_folder, "\n")
