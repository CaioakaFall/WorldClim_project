# 🌍 Análise de Artefatos Espaciais em Variáveis Bioclimáticas — WorldClim 2.1

## 📋 Descrição

Este projeto automatiza a identificação e a quantificação de **possíveis artefatos espaciais** em oito variáveis bioclimáticas do WorldClim 2.1, considerando os seis biomas terrestres brasileiros. O script `analise_artefatos.R` processa rasters regionais, produz máscaras de detecção, mapas e tabelas de áreas e percentuais.

São examinados dois padrões: **descontinuidades espaciais**, identificadas pelo procedimento C4, e **platôs espaciais**, identificados pelo procedimento V7. As detecções são candidatas a anomalias e requerem interpretação e validação científica; não demonstram, isoladamente, erros nos dados climáticos.

## 🎯 Objetivo

- Identificar padrões espaciais candidatos a descontinuidades e platôs em variáveis bioclimáticas.
- Quantificar as áreas e porcentagens detectadas em cada combinação de bioma e variável.
- Delimitar uma zona de risco de 10 km em torno das descontinuidades C4, sem confundi-la com a área originalmente detectada.
- Produzir mapas e planilhas padronizadas para avaliação e apresentação de resultados.
- Subsidiar a avaliação crítica e a seleção de preditores em modelos de nicho ecológico.

## 📁 Estrutura do Projeto

Os caminhos abaixo correspondem à configuração padrão do script. As pastas de saída são criadas automaticamente.

```text
C:/dados/
├── bioclim/                         # Rasters regionais WorldClim (.tif)
│   ├── Amazonia_BIO8.tif           # Exemplo de nome reconhecível
│   ├── Cerrado_BIO18.tif           # Exemplo de nome reconhecível
│   └── ...
├── rios/
│   └── massas_dagua_maior_20km2.gpkg  # Hidrografia opcional
└── analise_artefatos/              # Resultados gerados pelo script
    ├── rasters/                    # Máscaras C4, risco de 10 km e platôs
    ├── mapas/                      # Mapas PNG com título e legenda
    ├── mapa_sem_legenda/           # Mapas PNG sem título e legenda
    ├── tabelas/                    # CSV, XLSX, logs e validação
    ├── cache/                      # Arquivos intermediários reutilizáveis
    └── temp/                       # Arquivos temporários

ANALISE_ARTEFATOS_WORLDCLIM.R       # Script principal
README_ANALISE_ARTEFATOS.md         # Este arquivo
```

Os arquivos de entrada podem estar em subpastas de `bioclim/`. A busca exige que o nome de cada TIFF contenha o **bioma** e a **variável BIO**; deve haver exatamente um raster correspondente por combinação. Arquivos identificados como `BR` não são utilizados como entradas regionais.

## 🛠️ Pré-requisitos

### Bibliotecas R necessárias

```r
install.packages("terra")
install.packages("writexl")
```

O pacote `terra` é obrigatório. O pacote `writexl` é necessário quando `exportar_excel = TRUE` (configuração padrão); o script também tenta instalá-lo caso esteja ausente.

### Dependências do sistema

- R com versão compatível com os pacotes instalados; recomenda-se R 4.4 ou superior.
- RStudio (opcional, recomendado para acompanhar a execução).
- Espaço em disco e memória suficientes para processamento raster por blocos.
- Permissão de leitura dos dados de entrada e escrita na pasta de saída.
- Rasters com uma única camada e sistema de coordenadas em longitude/latitude, conforme validado pelo script.

## 📦 Instalação

1. Salve `analise_artefatos.R` em uma pasta de sua preferência.
2. Instale os pacotes R necessários.
3. Coloque os rasters regionais `.tif` em `C:/dados/bioclim/`.
4. Se desejar excluir massas d'água, coloque o arquivo vetorial em `C:/dados/rios/massas_dagua_maior_20km2.gpkg`.
5. Confira os diretórios e o modo de execução na configuração inicial do script.

## 🚀 Como Usar

### Execução básica

No RStudio ou console do R:

```r
source("analise_artefatos.R")
```

Ou no terminal, a partir da pasta onde está o arquivo:

```bash
Rscript analise_artefatos.R
```

### Configuração dos caminhos

No início do script, ajuste:

```r
CFG <- list(
  dados = "C:/dados/bioclim",
  rios = "C:/dados/rios/massas_dagua_maior_20km2.gpkg",
  saida = "C:/dados/analise_artefatos",
  # ... demais parâmetros já definidos no script
)
```

O trecho acima é **ilustrativo**: altere as três entradas no objeto `CFG` existente, sem substituir ou apagar os demais parâmetros.

### Modo piloto ou final

```r
modo = "piloto"  # Executa apenas as combinações definidas em CFG$piloto
modo = "final"   # Executa 6 biomas × 8 variáveis = 48 combinações
```

Use apenas uma dessas opções no parâmetro `modo`. O piloto configurado no script inclui quatro combinações de teste. **Os arquivos consolidados oficiais são gerados somente quando as 48 combinações são concluídas com sucesso.**

## 📊 Funcionalidades

### ✅ Verificações automáticas

- Confere a existência da pasta de rasters e procura entradas por bioma e variável.
- Verifica propriedades dos rasters e compatibilidade espacial das máscaras.
- Testa se todos os pixels C4 estão incluídos na respectiva zona de risco.
- Registra falhas de processamento e impede que execuções incompletas sejam apresentadas como resultados consolidados oficiais.

### 🔄 Processamento

- **Descontinuidades (C4):** aplicação do operador Sobel, seleção e conexão de candidatos e avaliação de perfil de degrau.
- **Platôs (V7):** identificação de núcleos espacialmente homogêneos e seleção por área mínima.
- **Hidrografia:** exclusão opcional das massas d'água, quando o vetor configurado está disponível.
- **Buffer:** expansão espacial de 10 km somente para as descontinuidades; os platôs não recebem buffer.
- **Quantificação:** cálculo de áreas (km²), percentuais e indicadores por bioma e variável.
- **Mapeamento:** geração de mapas com e sem legenda.

### 📈 Monitoramento

- Registra o andamento em `tabelas/execucao.txt`.
- Salva resultados parciais, tempos de processamento e eventuais erros.
- Utiliza cache de produtos intermediários para facilitar reexecuções.
- Exporta informações da configuração e do ambiente R para auditoria.

## 📝 Formato de Saída

### Máscaras raster (`rasters/`)

```text
[Bioma]_[BIO]_C4.tif           # Detecção original de descontinuidades
[Bioma]_[BIO]_risco_10km.tif   # Zona de risco de descontinuidades
[Bioma]_[BIO]_platos.tif       # Detecção de platôs
```

Cada tarefa produz somente os rasters correspondentes ao seu tipo de análise.

### Mapas (`mapas/` e `mapa_sem_legenda/`)

```text
[Bioma]_[BIO]_original.png
[Bioma]_[BIO]_risco_10km.png
[Bioma]_[BIO]_platos.png
```

### Planilhas e relatórios (`tabelas/`)

Quando **48/48 tarefas** terminam com status `OK`, os principais arquivos consolidados são:

| Arquivo | Conteúdo |
|---|---|
| `resultados_artigo.xlsx` | Planilha Excel com resumos, descontinuidades, platôs, matriz de porcentagens e dados para gráficos |
| `resumo_geral.csv` | Resultados consolidados por bioma e variável |
| `resumo_descontinuidades.csv` | Resultados das quatro variáveis de descontinuidade |
| `resumo_platos.csv` | Resultados das quatro variáveis de platô |
| `matriz_percentuais.csv` | Matriz de percentuais detectados para figuras |
| `dados_para_violino.csv` | Dados formatados para gráficos |
| `resumo_excel_br.csv` | Resumo CSV em formato compatível com convenções brasileiras |
| `VALIDACAO_FINAL.txt` | Estado da validação e das 48 tarefas |

Também são produzidos arquivos por tarefa (`*_areas.csv`), diagnósticos, `entradas.csv`, `tempos.csv`, `configuracao.rds` e `versoes_R.txt`. No modo piloto é gerado `resumo_piloto.csv`; em execuções incompletas é gerado `ATENCAO_resultado_INCOMPLETO.csv`, e os resultados oficiais consolidados são removidos.

**Interpretação dos percentuais:** `Pct_Detectada` corresponde à área da máscara original C4 ou V7. Para as descontinuidades, `Pct_Risco_10km` corresponde à zona de risco com buffer de 10 km. Esses valores não são intercambiáveis.

## 🔧 Configurações

### Variáveis analisadas

| Grupo | Variáveis | Método |
|---|---|---|
| Descontinuidades | BIO8, BIO9, BIO18, BIO19 | C4 |
| Platôs | BIO5, BIO6, BIO7, BIO14 | V7 |

### Principais parâmetros

```r
usar_agua = TRUE
cache = TRUE
refazer_mapas = FALSE
buffer_risco_km = 10
area_min_plato_km2 = 100
exportar_excel = TRUE
```

O script contém outros limiares e parâmetros calibrados. Alterá-los pode modificar as detecções e os resultados quantitativos.

### Sistema de coordenadas

Os rasters devem apresentar um CRS geográfico em longitude/latitude. O script não atribui automaticamente EPSG:4674 a arquivos sem referência espacial. Se necessário, a hidrografia é reprojetada para o CRS do raster; o cálculo do buffer sobre o raster geográfico é feito em metros pela função utilizada.

## ⚠️ Solução de Problemas

### Problemas comuns

1. **Pasta de entrada não encontrada:** confira `CFG$dados` e a existência de `C:/dados/bioclim/`.
2. **Raster não localizado ou duplicado:** verifique se o nome contém o bioma e o número BIO, e se há exatamente um arquivo correspondente.
3. **CRS inválido:** confira se os TIFFs possuem CRS geográfico válido, em longitude/latitude.
4. **Problemas de memória ou disco:** confira espaço livre em `temp/` e `cache/` e ajuste, se necessário, `memoria` e `bloco`.
5. **Hidrografia ausente:** revise `CFG$rios`; se não for utilizar a exclusão de massas d'água, defina `usar_agua = FALSE`.
6. **Execução incompleta:** consulte `tabelas/erros.csv`, `tabelas/execucao.txt` e `tabelas/VALIDACAO_FINAL.txt` antes de usar os resultados.

### Logs de erro

O arquivo `execucao.txt` registra o progresso. Quando há falhas, `erros.csv` apresenta as combinações afetadas. O cache pode acelerar novas execuções, mas sua existência não equivale a validação científica dos padrões detectados.

## 🌿 Biomas Suportados

- **Amazônia:** `Amazonia`
- **Caatinga:** `Caatinga`
- **Cerrado:** `Cerrado`
- **Mata Atlântica:** `Mata_Atlantica`
- **Pampa:** `Pampa`
- **Pantanal:** `Pantanal`

Os identificadores acima são os utilizados nos nomes de arquivo e na configuração do script.

## 🤝 Contribuições

Sugestões, correções e aprimoramentos metodológicos podem ser discutidos com o autor. Alterações nos algoritmos ou limiares devem ser documentadas para preservar a reprodutibilidade da análise.

## 📄 Licença

Licença ainda não definida. Este README não concede, por si só, permissão de redistribuição ou reutilização do código. Adicione um arquivo `LICENSE` quando a licença for escolhida.

## 👥 Autor

- **Caio Alexandre Barbosa**
- Universidade Federal do Espírito Santo (UFES)

## 📞 Suporte

Para dúvidas sobre a execução, consulte inicialmente `execucao.txt` e `VALIDACAO_FINAL.txt`.

**Última atualização:** novembro de 2026  
**Versão documentada:** C4 original + platôs V7  
**Ambiente recomendado:** R 4.4+; pacote `terra`; `writexl` para exportação Excel.
