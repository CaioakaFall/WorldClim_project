#=============================================================================
  # SCRIPT - CROP-MASK MCPs x BIOCLIMATIC VARIABLES (WORLDCLIM)
  # =============================================================================
# Objetivo: Criar MCPs (Minimum Convex Polygons) para espécies e recortar 
# variáveis bioclimáticas usando os MCPs como máscara
# =============================================================================

# 1. INSTALAR E CARREGAR BIBLIOTECAS NECESSÁRIAS
# =============================================================================
# Verificar e instalar pacotes se necessário
pacotes_necessarios <- c("sf", "raster", "dplyr", "sp", "readxl")
pacotes_nao_instalados <- pacotes_necessarios[!(pacotes_necessarios %in% installed.packages()[,"Package"])]

if(length(pacotes_nao_instalados) > 0) {
  cat("Instalando pacotes necessários...\n")
  install.packages(pacotes_nao_instalados)
}

# Carregar bibliotecas
library(sf)
library(raster)
library(dplyr)
library(sp)
library(readxl)

cat("Bibliotecas carregadas com sucesso!\n")

# 2. DEFINIR DIRETÓRIOS PRINCIPAIS
# =============================================================================
# Ajuste conforme a sua estrutura de pastas
dir_base <- "C:/tutorial"
dir_bioclim <- file.path(dir_base, "bioclim") # pasta com os 19 rasters bioclimáticos
dir_saida <- file.path(dir_base, "recortes_especies")
dir.create(dir_saida, showWarnings = FALSE)

cat("Diretórios configurados:\n")
cat("  Base:", dir_base, "\n")
cat("  Bioclim:", dir_bioclim, "\n")
cat("  Saída:", dir_saida, "\n")

# 3. CARREGAR DADOS DE PONTOS DE OCORRÊNCIA
# =============================================================================
# Tabela CSV com colunas: Especie, Latitude, Longitude
arquivo_ocorrencias <- file.path(dir_base, "ocorrencias.csv")

if(!file.exists(arquivo_ocorrencias)) {
  stop("ERRO: Arquivo de ocorrências não encontrado em: ", arquivo_ocorrencias)
}

# Carregar dados
dados <- read.csv(arquivo_ocorrencias, sep = ";", dec = ",")

# Verificar se as colunas necessárias existem
colunas_necessarias <- c("Especie", "Latitude", "Longitude")
colunas_faltantes <- colunas_necessarias[!(colunas_necessarias %in% names(dados))]

if(length(colunas_faltantes) > 0) {
  stop("ERRO: Colunas faltantes no arquivo CSV. Esperadas: ", paste(colunas_necessarias, collapse = ", "))
}

# Selecionar apenas as colunas necessárias
dados <- dados[, colunas_necessarias]

# Limpar e padronizar dados
dados$Latitude <- gsub(",", ".", dados$Latitude)
dados$Longitude <- gsub(",", ".", dados$Longitude)
dados$Latitude <- as.numeric(dados$Latitude)
dados$Longitude <- as.numeric(dados$Longitude)

# Arredondar coordenadas para 2 casas decimais
dados$Latitude <- round(dados$Latitude, digits = 2)
dados$Longitude <- round(dados$Longitude, digits = 2)

# Remover duplicatas
dados <- unique(dados)

# Remover linhas com valores ausentes nas coordenadas
dados <- dados[!is.na(dados$Latitude) & !is.na(dados$Longitude), ]

# Verificar se ainda há dados após a limpeza
if(nrow(dados) == 0) {
  stop("ERRO: Nenhum dado válido encontrado após remoção de valores ausentes")
}

# DIAGNÓSTICO: Verificar os dados carregados
cat("=== DIAGNÓSTICO DOS DADOS ===\n")
cat("Número de linhas carregadas:", nrow(dados), "\n")
cat("Número de colunas carregadas:", ncol(dados), "\n")
cat("Nomes das colunas encontradas:\n")
print(names(dados))
cat("Primeiras 3 linhas dos dados:\n")
print(head(dados, 3))
cat("Estrutura dos dados:\n")
str(dados)
cat("=== FIM DO DIAGNÓSTICO ===\n\n")

# Transformar em objeto sf
pontos <- st_as_sf(dados, coords = c("Longitude", "Latitude"), crs = 4674)

cat("Dados de ocorrência carregados:", nrow(dados), "registros de", length(unique(dados$Especie)), "espécies\n")

# 4. CARREGAR SHAPEFILE DOS BIOMAS DO BRASIL
# =============================================================================
arquivo_biomas <- file.path(dir_base, "Biomas.shp")

if(!file.exists(arquivo_biomas)) {
  cat("AVISO: Arquivo de biomas não encontrado. Pulando visualização.\n")
  biomas <- NULL
} else {
  biomas <- st_read(arquivo_biomas)
  cat("Shapefile de biomas carregado com sucesso!\n")
}

# 5. VISUALIZAÇÃO DOS PONTOS SOBRE OS BIOMAS
# =============================================================================
if(!is.null(biomas)) {
  # Criar paleta de cores para as espécies
  especies_unicas <- unique(dados$Especie)
  num_especies <- length(especies_unicas)
  cores_especies <- rainbow(num_especies)
  cores_mapeadas <- setNames(cores_especies, especies_unicas)
  
  # Plotar biomas
  plot(st_geometry(biomas), col = "lightgray", main = "Pontos de Ocorrência por Espécie sobre Biomas do Brasil")
  
  # Plotar pontos com cores diferentes para cada espécie
  for(especie in especies_unicas) {
    pontos_esp <- pontos %>% filter(Especie == especie)
    plot(st_geometry(pontos_esp), add = TRUE, col = cores_mapeadas[especie], pch = 20, cex = 0.8)
  }
  
  # Adicionar legenda
  legend("topright", legend = especies_unicas, col = cores_especies, pch = 20, cex = 0.7, 
         title = "Espécies", bg = "white")
}

# 6. CARREGAR RASTERS BIOCLIMÁTICOS (BIO1 A BIO19)
# =============================================================================
cat("Carregando rasters bioclimáticos...\n")
lista_rasters <- list()

for(i in 1:19) {
  nome_raster <- file.path(dir_bioclim, paste0("bio", i, ".tif"))
  
  if(!file.exists(nome_raster)) {
    stop("ERRO: Raster não encontrado: ", nome_raster)
  }
  
  lista_rasters[[i]] <- raster(nome_raster)
  cat("  bio", i, "carregado\n")
}

cat("Todos os 19 rasters bioclimáticos carregados com sucesso!\n")

# 7. LOOP PARA PROCESSAR CADA ESPÉCIE
# =============================================================================
especies <- unique(dados$Especie)
cat("\nIniciando processamento de", length(especies), "espécies...\n")

for(especie_atual in especies) {
  
  cat("\n" , rep("=", 50), "\n")
  cat("Processando espécie:", especie_atual, "\n")
  cat(rep("=", 50), "\n")
  
  # Selecionar pontos da espécie atual
  pontos_esp <- pontos %>% filter(Especie == especie_atual)
  
  if(nrow(pontos_esp) < 3) {
    cat("  AVISO: Espécie", especie_atual, "tem menos de 3 pontos. Pulando...\n")
    next
  }
  
  cat("  Número de pontos:", nrow(pontos_esp), "\n")
  
  # Criar polígono convexo mínimo (MCP)
  # =============================================================================
  cat("  Criando MCP (Minimum Convex Polygon)...\n")
  
  # Unir todos os pontos da espécie
  pontos_unidos <- st_union(pontos_esp)
  
  # Criar polígono convexo mínimo
  poligono_convexo <- st_convex_hull(pontos_unidos)
  
  # Aplicar buffer de 200 km 
  poligono_buffer <- st_buffer(poligono_convexo, dist = 200000)
  
  # Verificar e ajustar projeção para igualar ao raster
  poligono_buffer <- st_transform(poligono_buffer, crs = crs(lista_rasters[[1]]))
  
  # Converter para SpatialPolygons para compatibilidade com raster
  poligono_sp <- as(poligono_buffer, "Spatial")
  
  # Extrair a extensão do polígono para usar no crop
  extent_poligono <- extent(poligono_sp)
  
  cat("  MCP criado com sucesso!\n")
  
  # Criar pasta da espécie com sufixo MCP
  # =============================================================================
  nome_pasta <- paste0(gsub(" ", "_", especie_atual), "MCP")
  pasta_esp <- file.path(dir_saida, nome_pasta)
  dir.create(pasta_esp, showWarnings = FALSE)
  
  cat("  Pasta criada:", pasta_esp, "\n")
  
  # Loop para recortar todos os 19 rasters (CROP-MASK)
  # =============================================================================
  cat("  Iniciando recorte dos 19 rasters bioclimáticos...\n")
  
  for(i in 1:19) {
    
    raster_atual <- lista_rasters[[i]]
    
    # Crop e mask usando o MCP como máscara
    raster_crop <- crop(raster_atual, extent_poligono)
    raster_mask <- mask(raster_crop, poligono_sp)
    
    # Salvar raster resultante
    nome_saida <- file.path(pasta_esp, paste0("bio", i, "_", gsub(" ", "_", especie_atual), ".tif"))
    writeRaster(raster_mask, filename = nome_saida, format = "GTiff", overwrite = TRUE)
    
    cat("    bio", i, "recortado e salvo\n")
  }
  
  cat("  Processamento da espécie", especie_atual, "concluído!\n")
}

# =============================================================================
# CONCLUSÃO
# =============================================================================
cat("\n", rep("=", 60), "\n")
cat("PROCESSAMENTO CONCLUÍDO COM SUCESSO!\n")
cat(rep("=", 60), "\n")
cat("Resumo:\n")
cat("- Espécies processadas:", length(especies), "\n")
cat("- Rasters por espécie: 19 (bio1 a bio19)\n")
cat("- Pastas criadas:", length(especies), "\n")
cat("- Diretório de saída:", dir_saida, "\n")
cat("\nCada pasta contém os 19 rasters bioclimáticos recortados\n")
cat("usando o MCP (Minimum Convex Polygon) da respectiva espécie.\n")
cat(rep("=", 60), "\n")


