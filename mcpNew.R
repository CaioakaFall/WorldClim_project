pacotes_necessarios <- c("sf", "raster", "dplyr", "sp")
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

cat("Bibliotecas carregadas com sucesso!\n")

# 2. DEFINIR DIRETÓRIOS PRINCIPAIS
# =============================================================================
# Ajuste conforme a sua estrutura de pastas
dir_base <- "C:/Script_tutorial"
dir_bioclim <- file.path(dir_base, "bioclim") # pasta com os 19 rasters bioclimáticos
dir_saida <- file.path(dir_base, "recortes_especies")
dir.create(dir_saida, showWarnings = FALSE)

cat("Diretórios configurados:\n")
cat("  Base:", dir_base, "\n")
cat("  Bioclim:", dir_bioclim, "\n")
cat("  Saída:", dir_saida, "\n")

# 3. CARREGAR DADOS DE PONTOS DE OCORRÊNCIA
# =============================================================================
# Tabela CSV com colunas: especie, latitude, longitude
arquivo_ocorrencias <- file.path(dir_base, "ocorrencias.csv")

if(!file.exists(arquivo_ocorrencias)) {
  stop("ERRO: Arquivo de ocorrências não encontrado em: ", arquivo_ocorrencias)
}

dados <- read.csv(arquivo_ocorrencias)

# Verificar se as colunas necessárias existem
colunas_necessarias <- c("especie", "latitude", "longitude")
colunas_faltantes <- colunas_necessarias[!(colunas_necessarias %in% names(dados))]

if(length(colunas_faltantes) > 0) {
  stop("ERRO: Colunas faltantes no arquivo CSV: ", paste(colunas_faltantes, collapse = ", "))
}

# Transformar em objeto sf
pontos <- st_as_sf(dados, coords = c("longitude", "latitude"), crs = 4326)

cat("Dados de ocorrência carregados:", nrow(dados), "registros de", length(unique(dados$especie)), "espécies\n")

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
  plot(st_geometry(biomas), col = "lightgray", main = "Pontos de Ocorrência sobre Biomas do Brasil")
  plot(st_geometry(pontos), add = TRUE, col = "red", pch = 20, cex = 0.8)
  legend("topright", legend = "Pontos de ocorrência", col = "red", pch = 20, cex = 0.8)
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
especies <- unique(dados$especie)
cat("\nIniciando processamento de", length(especies), "espécies...\n")

for(especie_atual in especies) {
  
  cat("\n" , rep("=", 50), "\n")
  cat("Processando espécie:", especie_atual, "\n")
  cat(rep("=", 50), "\n")
  
  # Selecionar pontos da espécie atual
  pontos_esp <- pontos %>% filter(especie == especie_atual)
  
  if(nrow(pontos_esp) < 3) {
    cat("  AVISO: Espécie", especie_atual, "tem menos de 3 pontos. Pulando...\n")
    next
  }
  
  cat("  Número de pontos:", nrow(pontos_esp), "\n")
  
  # 3. CRIAR POLÍGONO CONVEXO MÍNIMO (MCP)
  # =============================================================================
  cat("  Criando MCP (Minimum Convex Polygon)...\n")
  
  # Unir todos os pontos da espécie
  pontos_unidos <- st_union(pontos_esp)
  
  # Criar polígono convexo mínimo
  poligono_convexo <- st_convex_hull(pontos_unidos)
  
  # Aplicar buffer de 1 km
  poligono_buffer <- st_buffer(poligono_convexo, dist = 1000)
  
  # Verificar e ajustar projeção para igualar ao raster
  poligono_buffer <- st_transform(poligono_buffer, crs = crs(lista_rasters[[1]]))
  
  cat("  MCP criado com sucesso!\n")
  
  # Criar pasta da espécie com sufixo MCP
  # =============================================================================
  nome_pasta <- paste0(gsub(" ", "_", especie_atual), "MCP")
  pasta_esp <- file.path(dir_saida, nome_pasta)
  dir.create(pasta_esp, showWarnings = FALSE)
  
  cat("  Pasta criada:", pasta_esp, "\n")
  
  # 4. LOOP PARA RECORTAR TODOS OS 19 RASTERS (CROP-MASK)
  # =============================================================================
  cat("  Iniciando recorte dos 19 rasters bioclimáticos...\n")
  
  for(i in 1:19) {
    
    raster_atual <- lista_rasters[[i]]
    
    # Crop e mask usando o MCP como máscara
    raster_crop <- crop(raster_atual, poligono_buffer)
    raster_mask <- mask(raster_crop, poligono_buffer)
    
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