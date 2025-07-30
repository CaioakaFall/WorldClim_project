# 🌍 Crop e Mask de Rasters com Vetores

## 📋 Descrição

Este projeto automatiza o processo de recorte e mascaramento de rasters (.tif) usando vetores (.gpkg) como referência. O script aplica operações de `crop` e `mask` para cada combinação de raster e vetor, gerando arquivos processados organizados por bioma.

## 🎯 Objetivo

- Recortar rasters de variáveis bioclimáticas usando vetores de biomas brasileiros
- Aplicar máscara para manter apenas os dados dentro dos limites dos vetores
- Gerar arquivos processados com nomenclatura padronizada
- Automatizar o processamento para múltiplas combinações

## 📁 Estrutura do Projeto

```
CM/
├── camadas/           # Rasters de entrada (.tif)
│   ├── wc2.1_30s_bio_1.tif
│   ├── wc2.1_30s_bio_2.tif
│   └── ...
├── vetores/          # Vetores de biomas (.gpkg)
│   ├── amazonia.gpkg
│   ├── cerrado.gpkg
│   ├── caatinga.gpkg
│   ├── mata_atlantica.gpkg
│   ├── pampa.gpkg
│   ├── pantanal.gpkg
│   └── BR.gpkg
├── resultados/       # Rasters processados (.tif)
│   ├── wc2.1_30s_bio_1_amazonia_masked.tif
│   ├── wc2.1_30s_bio_1_cerrado_masked.tif
│   └── ...
├── funfando.R       # Script principal
└── README_CM.md     # Este arquivo
```

## 🛠️ Pré-requisitos

### Bibliotecas R Necessárias

```r
# Instalar bibliotecas (executar apenas uma vez)
install.packages("terra")
install.packages("sf")
```

### Dependências do Sistema

- R (versão 4.0 ou superior)
- RStudio (recomendado)
- Acesso de escrita no diretório do projeto

## 📦 Instalação

1. **Clone o repositório:**
   ```bash
   git clone [URL_DO_REPOSITORIO]
   cd CM
   ```

2. **Instale as bibliotecas R:**
   ```r
   install.packages("terra")
   install.packages("sf")
   ```

3. **Prepare os dados:**
   - Coloque os rasters (.tif) na pasta `camadas/`
   - Coloque os vetores (.gpkg) na pasta `vetores/`
   - Certifique-se de que os vetores estão no CRS correto (EPSG:4674)

## 🚀 Como Usar

### Execução Básica

1. **Abra o RStudio e carregue o script:**
   ```r
   source("funfando.R")
   ```

2. **Ou execute diretamente:**
   ```r
   Rscript funfando.R
   ```

### Configuração dos Caminhos

O script está configurado para usar a estrutura de pastas `C:/CM/`. Se necessário, ajuste os caminhos no script:

```r
# Caminhos para as pastas
bio_folder <- "C:/CM/camadas/"
vetores_folder <- "C:/CM/vetores/"
resultados_folder <- "C:/CM/resultados/"
```

## 📊 Funcionalidades

### ✅ Verificações Automáticas

- **Existência de pastas:** Cria automaticamente se não existirem
- **Arquivos de entrada:** Verifica se há rasters e vetores disponíveis
- **Resultados vazios:** Detecta e reporta processamentos sem dados válidos

### 🔄 Processamento

- **Crop:** Recorta o raster para a extensão do vetor
- **Mask:** Aplica máscara para manter apenas dados dentro do vetor
- **CRS:** Define automaticamente o sistema de coordenadas (EPSG:4674)

### 📈 Monitoramento

- **Progresso:** Mostra o progresso do processamento
- **Logs:** Registra cada operação realizada
- **Visualização:** Plota o primeiro resultado válido

## 📝 Formato de Saída

Os arquivos processados seguem o padrão:
```
[nome_do_raster]_[nome_do_vetor]_masked.tif
```

**Exemplo:**
- `wc2.1_30s_bio_1_amazonia_masked.tif`
- `wc2.1_30s_bio_1_cerrado_masked.tif`

## 🔧 Configurações

### CRS (Sistema de Coordenadas)

O script está configurado para usar EPSG:4674 (SIRGAS 2000). Para alterar:

```r
crs(vetor) <- "EPSG:4674"  # Altere conforme necessário
```

### Padrão de Arquivos

Para alterar os padrões de busca:

```r
# Rasters (.tif)
bio_files <- list.files(path = bio_folder, pattern = '\\.tif$', full.names = TRUE)

# Vetores (.gpkg)
vetores_files <- list.files(path = vetores_folder, pattern = '\\.gpkg$', full.names = TRUE)
```

## ⚠️ Troubleshooting

### Problemas Comuns

1. **Erro de CRS:**
   - Verifique se os vetores estão no CRS correto
   - Ajuste a linha `crs(vetor) <- "EPSG:4674"`

2. **Resultados vazios:**
   - Verifique se os vetores e rasters se sobrepõem
   - Confirme se os dados estão na mesma região

3. **Erro de memória:**
   - Processe arquivos menores
   - Divida o processamento em lotes

### Logs de Erro

O script fornece logs detalhados:
- Arquivos encontrados
- Progresso do processamento
- Avisos sobre resultados vazios
- Confirmação de salvamento

## 📊 Biomas Suportados

- **Amazônia:** `amazonia.gpkg`
- **Cerrado:** `cerrado.gpkg`
- **Caatinga:** `caatinga.gpkg`
- **Mata Atlântica:** `mata_atlantica.gpkg`
- **Pampa:** `pampa.gpkg`
- **Pantanal:** `pantanal.gpkg`
- **Brasil:** `BR.gpkg`

## 🤝 Contribuição

Para contribuir com o projeto:

1. Faça um fork do repositório
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença [ESPECIFICAR_LICENÇA].

## 👥 Autores

- [Seu Nome]
- [Instituição]

## 📞 Suporte

Para dúvidas ou problemas:
- Abra uma issue no GitHub
- Entre em contato: [seu_email@exemplo.com]

---

**Última atualização:** [DATA]
**Versão:** 1.0.0
