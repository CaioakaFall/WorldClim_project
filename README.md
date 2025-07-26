# 📊 Processamento de Dados Biogeográficos - MCP e Variáveis Bioclimáticas

## 📋 Descrição

Este projeto contém scripts em R para processamento de dados biogeográficos, especificamente para criar **MCPs (Minimum Convex Polygons)** para espécies e recortar variáveis bioclimáticas usando os MCPs como máscara. O script principal (`Caio_selecao.R`) automatiza todo o processo de análise espacial para múltiplas espécies.

## 🎯 Objetivos

- Criar polígonos convexos mínimos (MCPs) para cada espécie
- Recortar 19 variáveis bioclimáticas (bio1 a bio19) usando os MCPs como máscara
- Gerar visualizações dos pontos de ocorrência sobre biomas
- Organizar os resultados em pastas estruturadas por espécie

## 📁 Estrutura do Projeto

```
tutorial/
├── mcpNew.R                    # Script principal
├── ocorrencias.csv             # Dados de pontos de ocorrência
├── bioclim/                    # Rasters bioclimáticos (bio1.tif a bio19.tif)
│   ├── bio1.tif
│   ├── bio2.tif
│   └── ... (até bio19.tif)
├── Biomas.shp                  # Shapefile dos biomas do Brasil
├── recortes_especies/          # Pasta de saída (criada automaticamente)
│   ├── Especie1_MCP/
│   ├── Especie2_MCP/
│   └── ...
└── README.md                   # Este arquivo
```

## 🔧 Pré-requisitos

### Software
- **R** (versão 4.0 ou superior)
- **RStudio** (recomendado)

### Pacotes R Necessários
O script instala automaticamente os seguintes pacotes:
- `sf` - Análise espacial
- `raster` - Manipulação de rasters
- `dplyr` - Manipulação de dados
- `sp` - Classes e métodos para dados espaciais
- `readxl` - Leitura de arquivos Excel

### Dados Necessários
1. **Arquivo CSV de ocorrências** (`ocorrencias.csv`) com colunas:
   - `Especie`: Nome da espécie
   - `Latitude`: Latitude (decimal, vírgula como separador)
   - `Longitude`: Longitude (decimal, vírgula como separador)

2. **Rasters bioclimáticos** (19 arquivos .tif):
   - `bio1.tif` a `bio19.tif`
   - Formato: GeoTIFF
   - Projeção: Compatível com os dados de ocorrência

3. **Shapefile de biomas** (opcional):
   - `Biomas.shp` e arquivos relacionados
   - Para visualização dos pontos sobre biomas

## 🚀 Como Usar

### 1. Preparação dos Dados
```bash
# Certifique-se de que os arquivos estão na estrutura correta:
# - ocorrencias.csv na pasta raiz
# - Rasters bioclimáticos na pasta bioclim/
# - Shapefile de biomas na pasta raiz (opcional)
```

### 2. Execução do Script
```r
# No R ou RStudio, execute:
source("mcpNew.R")
```

### 3. Configuração de Diretórios
O script está configurado para:
- **Diretório base**: `C:/tutorial`
- **Rasters bioclimáticos**: `C:/tutorial/bioclim`
- **Saída**: `C:/tutorial/recortes_especies`

Para alterar os diretórios, edite as linhas 32-34 do script:
```r
dir_base <- "C:/Script_tutorial"
dir_bioclim <- file.path(dir_base, "bioclim")
dir_saida <- file.path(dir_base, "recortes_especies")
```

## 📊 Funcionalidades

### 1. Carregamento e Limpeza de Dados
- Leitura automática do arquivo CSV
- Verificação de colunas necessárias
- Limpeza de coordenadas (substituição de vírgulas por pontos)
- Remoção de duplicatas
- Arredondamento para 2 casas decimais
- Remoção de valores ausentes

### 2. Visualização
- Plotagem dos pontos de ocorrência sobre biomas
- Cores diferentes para cada espécie
- Legenda automática

### 3. Criação de MCPs
- Polígono convexo mínimo para cada espécie
- Buffer de 10 km aplicado ao MCP
- Transformação de projeção para compatibilidade com rasters

### 4. Recorte de Rasters
- Processamento dos 19 rasters bioclimáticos
- Operações de crop e mask usando MCP como máscara
- Salvamento em formato GeoTIFF

### 5. Organização de Saída
- Criação automática de pastas por espécie
- Nomenclatura: `NomeEspecie_MCP`
- 19 arquivos por espécie (bio1 a bio19)

## 📈 Exemplo de Saída

```
recortes_especies/
├── Callithrix_penicillata_MCP/
│   ├── bio1_Callithrix_penicillata.tif
│   ├── bio2_Callithrix_penicillata.tif
│   ├── bio3_Callithrix_penicillata.tif
│   └── ... (até bio19)
├── Outra_especie_MCP/
│   ├── bio1_Outra_especie.tif
│   └── ...
└── ...
```

## ⚠️ Considerações Importantes

### Limitações
- Espécies com menos de 3 pontos são puladas
- Requer memória suficiente para carregar 19 rasters simultaneamente
- Processamento pode ser lento para muitas espécies

### Validação de Dados
- Verificação automática de arquivos necessários
- Diagnóstico detalhado dos dados carregados
- Tratamento de erros com mensagens informativas

### Projeções
- Os dados de ocorrência são assumidos em CRS 4674 (SIRGAS 2000)
- Os rasters são reprojetados automaticamente se necessário

## 🔍 Diagnóstico e Logs

O script fornece informações detalhadas durante a execução:
- Número de registros carregados
- Número de espécies processadas
- Progresso do processamento por espécie
- Resumo final com estatísticas

## 🛠️ Solução de Problemas

### Erro: "Arquivo de ocorrências não encontrado"
- Verifique se `ocorrencias.csv` está na pasta correta
- Confirme o nome do arquivo

### Erro: "Raster não encontrado"
- Verifique se todos os arquivos bio1.tif a bio19.tif estão na pasta `bioclim/`
- Confirme os nomes dos arquivos

### Erro: "Colunas faltantes"
- Verifique se o CSV tem as colunas: Especie, Latitude, Longitude
- Confirme o separador (;) e decimal (,)

### Problemas de Memória
- Processe menos espécies por vez
- Feche outros programas
- Considere usar um computador com mais RAM

## 📝 Formato dos Dados de Entrada

### Exemplo de ocorrencias.csv:
```csv
Especie;Latitude;Longitude
Callithrix penicillata;-14,26149722;-39,00139722
Callithrix penicillata;-13,49;-39,04999722
Outra especie;-15,862082;-47,828741
```

## 🤝 Contribuições

Para contribuir com o projeto:
1. Faça um fork do repositório
2. Commit suas mudanças

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.

## 👥 Autores

- Desenvolvido para análise biogeográfica
- Script otimizado para processamento de dados de biodiversidade

## 📞 Suporte

Para dúvidas ou problemas:
- Abra uma issue no GitHub
- Verifique a seção de solução de problemas acima
- Consulte a documentação dos pacotes R utilizados

---

**Última atualização**: Dezembro 2024
**Versão**: 1.0
**Compatibilidade**: R 4.0+
