# 📊 Processamento de Dados Biogeográficos

Script R para processamento automatizado de dados de ocorrência de espécies e variáveis bioclimáticas, criando MCPs (Minimum Convex Polygons) e recortando rasters ambientais.

## 🎯 Objetivo

Este projeto automatiza o processamento de dados biogeográficos para análise de distribuição de espécies, incluindo:

- **Criação de MCPs** (Minimum Convex Polygons) para cada espécie
- **Recorte de variáveis bioclimáticas** (bio1-bio19) usando os MCPs como máscara
- **Organização automática** dos resultados em pastas estruturadas
- **Visualização** dos pontos de ocorrência sobre biomas do Brasil

## 📋 Pré-requisitos

### Software Necessário
- **R** (versão 4.0 ou superior)
- **RStudio** (recomendado)

### Pacotes R
O script instala automaticamente os seguintes pacotes:
- `sf` - Para dados espaciais vetoriais
- `raster` - Para dados raster
- `dplyr` - Para manipulação de dados
- `sp` - Para dados espaciais

## 📁 Estrutura de Arquivos

```
projeto/
├── script                    # Script principal R
├── README.md                 # Este arquivo
├── dados/                    # Pasta com dados de entrada
│   ├── ocorrencias.csv      # Dados de ocorrência das espécies
│   ├── Biomas.shp           # Shapefile dos biomas do Brasil
│   └── bioclim/             # Rasters bioclimáticos
│       ├── bio1.tif
│       ├── bio2.tif
│       └── ... (até bio19)
└── resultados/              # Pasta de saída (criada automaticamente)
    ├── especie1MCP/
    ├── especie2MCP/
    └── ...
```

## 📊 Formato dos Dados de Entrada

### Arquivo CSV de Ocorrências
O arquivo `ocorrencias.csv` deve conter as seguintes colunas:

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `especie` | Texto | Nome da espécie |
| `latitude` | Numérico | Latitude em graus decimais |
| `longitude` | Numérico | Longitude em graus decimais |

**Exemplo:**
```csv
especie,latitude,longitude
Araucaria_angustifolia,-25.4283,-49.2733
Araucaria_angustifolia,-25.4167,-49.2500
Euterpe_edulis,-23.5505,-46.6333
```

### Rasters Bioclimáticos
- **Formato:** GeoTIFF (.tif)
- **Nomenclatura:** `bio1.tif`, `bio2.tif`, ..., `bio19.tif`
- **Origem:** WorldClim ou similar
- **Resolução:** Recomendado 30 arc-seconds ou superior

### Shapefile de Biomas
- **Formato:** Shapefile (.shp)
- **Escopo:** Biomas do Brasil
- **Sistema de Coordenadas:** WGS84 (EPSG:4326)

## 🚀 Como Usar

### 1. Preparação dos Dados
1. Organize seus dados na estrutura de pastas mostrada acima
2. Certifique-se de que o arquivo CSV tem as colunas corretas
3. Verifique se todos os 19 rasters bioclimáticos estão presentes

### 2. Configuração do Script
Edite a linha 25 do script para apontar para seu diretório base:

```r
dir_base <- "C:/caminho/para/seu/projeto"
```

### 3. Execução
```r
# No R ou RStudio
source("script")
```

### 4. Monitoramento
O script fornece feedback detalhado durante a execução:
- ✅ Carregamento de bibliotecas
- ✅ Verificação de arquivos
- ✅ Progresso por espécie
- ✅ Resumo final

## 📈 Resultados

### Estrutura de Saída
Para cada espécie, uma pasta é criada com o sufixo "MCP":

```
resultados/
├── Araucaria_angustifoliaMCP/
│   ├── bio1_Araucaria_angustifolia.tif
│   ├── bio2_Araucaria_angustifolia.tif
│   └── ... (até bio19)
├── Euterpe_edulisMCP/
│   ├── bio1_Euterpe_edulis.tif
│   ├── bio2_Euterpe_edulis.tif
│   └── ... (até bio19)
└── ...
```

### Produtos Gerados
- **MCPs** com buffer de 1km para cada espécie
- **19 rasters recortados** por espécie (bio1-bio19)
- **Visualização** dos pontos sobre biomas
- **Relatório** de processamento

## ⚠️ Considerações Importantes

### Limitações
- **Mínimo de pontos:** Espécies com menos de 30 pontos são puladas
- **Memória:** Processamento de muitos rasters pode exigir RAM considerável
- **Tempo:** Depende do número de espécies e resolução dos rasters

### Recomendações
- **Backup:** Faça backup dos dados originais
- **Teste:** Execute primeiro com um subconjunto de dados
- **Monitoramento:** Acompanhe o uso de memória durante execução

## 🔧 Personalização

### Modificar Buffer
Para alterar o buffer do MCP (padrão: 1km):

```r
# Linha 108 - alterar o valor 1000 (metros)
poligono_buffer <- st_buffer(poligono_convexo, dist = 2000)  # 2km
```

### Adicionar Variáveis
Para incluir variáveis adicionais além das bioclimáticas:

```r
# Adicionar novos rasters na lista
lista_rasters[[20]] <- raster("nova_variavel.tif")
```

## 🐛 Solução de Problemas

### Erro: "Arquivo não encontrado"
- Verifique se os caminhos estão corretos
- Confirme se os arquivos existem nas pastas especificadas

### Erro: "Colunas faltantes"
- Verifique se o CSV tem as colunas: `especie`, `latitude`, `longitude`
- Confirme se os nomes das colunas estão escritos corretamente

### Erro de Memória
- Reduza o número de espécies processadas por vez
- Considere usar rasters com resolução menor

## 📚 Referências

- **WorldClim:** [worldclim.org](https://worldclim.org/)
- **sf package:** [r-spatial.github.io/sf/](https://r-spatial.github.io/sf/)
- **raster package:** [cran.r-project.org/package=raster](https://cran.r-project.org/package=raster)

## 🤝 Contribuições

Contribuições são bem-vindas! Para contribuir:

1. Faça um fork do projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## 👥 Autores

- **Desenvolvido para:** Análise biogeográfica de espécies
- **Linguagem:** R
- **Versão:** 1.0

---

**⭐ Se este projeto foi útil, considere dar uma estrela no GitHub!** # projectWC
