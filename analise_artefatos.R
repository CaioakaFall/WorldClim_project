# Analise de artefatos espaciais em variaveis bioclimaticas - WorldClim 2.1
# Autor: Caio Alexandre Barbosa

# Configuracao

if (!requireNamespace("terra", quietly=TRUE)) {
  stop("Instale o pacote terra: install.packages('terra')")
}
suppressPackageStartupMessages(library(terra))
CFG <- list(
dados = "C:/dados/bioclim",
rios = "C:/dados/rios/massas_dagua_maior_20km2.gpkg",
saida = "C:/dados/analise_artefatos",
modo = "final",
biomas = c("Amazonia","Caatinga","Cerrado","Mata_Atlantica","Pampa","Pantanal"),
linhas = c("BIO8","BIO9","BIO18","BIO19"),
platos = c("BIO5","BIO6","BIO7","BIO14"),
piloto = data.frame(Bioma=c("Pampa","Mata_Atlantica","Amazonia","Cerrado"),
Variavel=c("BIO18","BIO8","BIO18","BIO14")),
usar_agua = TRUE,
cache = TRUE,
refazer_mapas = FALSE,
memoria = 0.35,
bloco = 64L, halo = 18L,
q_mag_fraco=0.55,q_mag_forte=0.83,
q_score_fraco=0.48,q_score_forte=0.78,
score_fraco_min=0.95,score_forte_min=1.20,
histerese=12L,
suporte_principal=6L,direcao_principal=4L,
suporte_secundario=4L,direcao_secundaria=3L,
conectar=TRUE,
salto_forte=c(BIO8=0.8,BIO9=0.8,BIO18=15,BIO19=15),
salto_fraco=c(BIO8=0.4,BIO9=0.4,BIO18=7.5,BIO19=7.5),
razao_forte=4.0,razao_fraca=3.0,
suporte_c4=4L,suporte_referencia_ponte=5L,
ponte_salto_frac=0.85,ponte_mag_frac=0.50,
buffer_risco_km = 10,
cor_linhas = "#E65C00",
cor_platos = "#88419D",
transparencia_risco = 0.50,
quantum=c(BIO5=0.1,BIO6=0.1,BIO7=0.1,BIO14=1),
area_min_plato_km2=100,
excluir_bio14_muito_seco=FALSE,
bio14_seco_mm=2,
max_celulas_png=1800000L,
exportar_excel=TRUE
)
VERSAO <- "C4_original_platos_V7"
if (!CFG$modo %in% c("piloto","final")) stop("Modo desconhecido")
if (CFG$halo < CFG$histerese + 4L) stop("Halo insuficiente")
stopifnot(CFG$suporte_c4==4L,CFG$suporte_referencia_ponte==5L,
CFG$transparencia_risco>=0,CFG$transparencia_risco<=1,
CFG$buffer_risco_km==10)
if (!dir.exists(CFG$dados)) stop("Pasta de dados bioclimaticos nao encontrada: ", CFG$dados)
DIR <- list(
dados = CFG$dados,
base = CFG$saida,
rasters = file.path(CFG$saida,"rasters"),
mapas = file.path(CFG$saida,"mapas"),
sem_legenda = file.path(CFG$saida,"mapa_sem_legenda"),
tabelas = file.path(CFG$saida,"tabelas"),
cache = file.path(CFG$saida,"cache"),
temp = file.path(CFG$saida,"temp")
)
for (d in unique(unlist(DIR[-1])))
dir.create(d,recursive=TRUE,showWarnings=FALSE)
if (!dir.exists(DIR$base)) stop("Nao foi possivel criar pasta: ",DIR$base)
if (isTRUE(CFG$exportar_excel) && !requireNamespace("writexl",quietly=TRUE)) {
  message("Instalando writexl uma unica vez (necessario para resultados_artigo.xlsx)...")
  try(utils::install.packages("writexl",repos="https://cloud.r-project.org"),silent=TRUE)
}
if (isTRUE(CFG$exportar_excel) && !requireNamespace("writexl",quietly=TRUE))
stop("Pacote writexl indisponivel. Instale install.packages('writexl') antes de rodar a analise.")
CFG$agua <- CFG$rios
terra::terraOptions(memfrac=CFG$memoria,tempdir=DIR$temp,progress=1)
set.seed(20261101)
LOG <- file.path(DIR$tabelas,"execucao.txt")
logar <- function(...) {
  msg <- paste0("[",format(Sys.time(),"%Y-%m-%d %H:%M:%S"),"] ",
  paste0(...,collapse=""))
  cat(msg,"\n");cat(msg,"\n",file=LOG,append=TRUE);flush.console()
}
salvar <- function(r,f) {
  terra::writeRaster(r,f,overwrite=TRUE,
  wopt=list(gdal="COMPRESS=LZW"))
  terra::rast(f)
}
assinar <- function(f) {
  if(!file.exists(f)) return(NULL)
  x<-file.info(f)
  list(arquivo=normalizePath(f,winslash="/"),
  tamanho=as.numeric(x$size),data=as.numeric(x$mtime))
}
cache_ok <- function(arquivo,meta,sig,modelo=NULL) {
  isTRUE(CFG$cache) && file.exists(arquivo) && file.exists(meta) &&
  identical(tryCatch(readRDS(meta),error=function(e)NULL),sig) &&
  (is.null(modelo) || terra::compareGeom(terra::rast(arquivo),modelo,stopOnError=FALSE))
}

# Arquivos de entrada e hidrografia

normalizar <- function(x) {
  x <- iconv(as.character(x),to="ASCII//TRANSLIT")
  gsub("[^a-z0-9]+","_",tolower(x))
}
ARQUIVOS <- list.files(DIR$dados,"\\.tif(f)?$",recursive=TRUE,
full.names=TRUE,ignore.case=TRUE)
if (!length(ARQUIVOS)) stop("Nenhum arquivo raster na pasta: ",DIR$dados)
NOMES <- normalizar(ARQUIVOS)
localizar <- function(bio,bioma) {
  numero <- as.integer(sub("BIO","",bio))
  ok <- grepl(paste0("(^|_)bio_?0*",numero,"(_|$)"),NOMES,perl=TRUE) &
  grepl(paste0("(^|_)",normalizar(bioma),"(_|$)"),NOMES,perl=TRUE) &
  !grepl("(^|_)br(_|$)",NOMES,perl=TRUE)
  arqs <- ARQUIVOS[ok]
  if(length(arqs)!=1L) stop("Esperado exatamente um TIFF regional para ",
  bioma,"/",bio,"; encontrados: ",length(arqs))
  arqs
}
preparar_agua <- function(r,bio,bioma,origem) {
  if(!isTRUE(CFG$usar_agua) || !file.exists(CFG$agua)) return(r)
  arq <- file.path(DIR$cache,paste0(bioma,"_",bio,"_sem_agua.tif"))
  meta<-paste0(arq,".rds")
  sig <- list(entrada=assinar(origem),hidrografia=assinar(CFG$agua))
  if(cache_ok(arq,meta,sig,r)) return(terra::rast(arq))
  agua <- terra::vect(CFG$agua)
  if(!terra::same.crs(agua,r)) agua<-terra::project(agua,terra::crs(r))
  agua<-tryCatch(terra::crop(agua,terra::ext(r)),error=function(e)NULL)
  if(is.null(agua) || nrow(agua)==0L) return(r)
  marca <- terra::rasterize(agua,r,field=1,background=0,touches=TRUE)
  terra::ifel(marca==1,NA,r,filename=arq,overwrite=TRUE,
  wopt=list(gdal="COMPRESS=LZW"))
  saveRDS(sig,meta)
  terra::rast(arq)
}

# Funcoes auxiliares

deslocar <- function(
x, dr = 0L, dc = 0L,
preencher = NA_real_
) {
  nr <- nrow(x)
  nc <- ncol(x)
  z <- matrix(preencher, nr, nc)
  r1 <- max(1L, 1L - dr)
  r2 <- min(nr, nr - dr)
  c1 <- max(1L, 1L - dc)
  c2 <- min(nc, nc - dc)
  if (r1 > r2 || c1 > c2) return(z)
  rr <- r1:r2
  cc <- c1:c2
  z[rr, cc] <- x[
  rr + dr, cc + dc, drop = FALSE
  ]
  z
}
DIRECOES <- list(
c(-1L,-1L), c(-1L,0L), c(-1L,1L),
c(0L,-1L), c(0L,1L),
c(1L,-1L), c(1L,0L), c(1L,1L)
)
contar <- function(x, raio = 3L) {
  z <- matrix(0L, nrow(x), ncol(x))
  for (dr in (-raio):raio) {
    for (dc in (-raio):raio) {
      z <- z + as.integer(
      deslocar(x, dr, dc, FALSE)
      )
    }
  }
  z
}
vizinhos <- function(x) {
  z <- matrix(FALSE, nrow(x), ncol(x))
  for (d in DIRECOES) {
    z <- z | deslocar(
    x, d[1], d[2], FALSE
    )
  }
  z
}
suporte_direcional <- function(x) {
  dirs <- list(
  c(0L,1L), c(1L,0L),
  c(1L,1L), c(1L,-1L)
  )
  maior <- matrix(0L, nrow(x), ncol(x))
  for (d in dirs) {
    s <- matrix(0L, nrow(x), ncol(x))
    for (k in -3:3) {
      s <- s + as.integer(
      deslocar(
      x, k*d[1], k*d[2], FALSE
      )
      )
    }
    maior <- pmax(maior, s)
  }
  maior
}
quantil <- function(x, p, padrao = NA_real_) {
  x <- x[is.finite(x)]
  if (length(x) < 30L) return(padrao)
  as.numeric(stats::quantile(
  x, p, names = FALSE
  ))
}
amostrar <- function(r, n = 12000L) {
  z <- terra::spatSample(
  r, size = n,
  method = "regular",
  values = TRUE,
  na.rm = TRUE,
  as.df = FALSE
  )
  z <- as.numeric(z)
  z[is.finite(z)]
}
escala_temperatura <- function(r, bio) {
  if (!bio %in% c(
  "BIO1","BIO5","BIO6","BIO7","BIO8","BIO9"
  )) return(1)
  z <- amostrar(r, 300L)
  if (!length(z)) return(1)
  if (max(abs(z)) > 100) 10 else 1
}
ler_matriz <- function(r, a, nl) {
  matrix(
  as.numeric(terra::readValues(
  r, row = a, nrows = nl
  )),
  nrow = nl,
  ncol = terra::ncol(r),
  byrow = TRUE
  )
}

# Operador Sobel e afinamento

sobel <- function(x) {
  N <- deslocar(x,-1,0)
  S <- deslocar(x, 1,0)
  E <- deslocar(x,0,1)
  W <- deslocar(x,0,-1)
  NE <- deslocar(x,-1,1)
  NW <- deslocar(x,-1,-1)
  SE <- deslocar(x,1,1)
  SW <- deslocar(x,1,-1)
  gx <- (NE + 2*E + SE - NW - 2*W - SW)/8
  gy <- (SW + 2*S + SE - NW - 2*N - NE)/8
  mag <- sqrt(gx^2 + gy^2)
  seguro <- is.finite(x)
  for (d in DIRECOES) {
    seguro <- seguro & is.finite(
    deslocar(x,d[1],d[2])
    )
  }
  for (d in DIRECOES) {
    seguro <- seguro & deslocar(
    is.finite(x),
    d[1],d[2],FALSE
    )
  }
  mag[!seguro] <- NA_real_
  gx[!seguro] <- NA_real_
  gy[!seguro] <- NA_real_
  soma <- matrix(0, nrow(x), ncol(x))
  n <- matrix(0L, nrow(x), ncol(x))
  for (dr in -1:1) {
    for (dc in -1:1) {
      z <- deslocar(mag,dr,dc)
      ok <- is.finite(z)
      soma[ok] <- soma[ok] + z[ok]
      n <- n + as.integer(ok)
    }
  }
  media <- soma/pmax(n,1L)
  positivos <- mag[is.finite(mag) & mag > 0]
  piso <- if (length(positivos)) {
    max(quantil(positivos,0.10,1e-8),1e-8)
  } else {
    1e-8
  }
  score <- mag/(media + 0.15*piso)
  ax <- abs(gx)
  ay <- abs(gy)
  direcao <- ifelse(
  ax >= 2.414*ay, 1L,
  ifelse(
  ay >= 2.414*ax, 2L,
  ifelse(gx*gy >= 0, 3L, 4L)
  )
  )
  pares <- list(
  c(0L,1L),c(1L,0L),
  c(1L,1L),c(1L,-1L)
  )
  crista <- matrix(
  FALSE,nrow(x),ncol(x)
  )
  for (i in seq_along(pares)) {
    d <- pares[[i]]
    v1 <- deslocar(mag,d[1],d[2])
    v2 <- deslocar(mag,-d[1],-d[2])
    crista <- crista | (
    direcao == i &
    mag >= v1 &
    mag > v2 &
    is.finite(mag)
    )
  }
  crista[is.na(crista)] <- FALSE
  list(
  gx = gx, gy = gy,
  mag = mag, score = score,
  crista = crista, seguro = seguro
  )
}

# Calibracao das descontinuidades

calibrar_linhas <- function(r, escala) {
  nr <- terra::nrow(r)
  nc <- terra::ncol(r)
  centros <- unique(as.integer(
  seq(1,nr,length.out = 9L)
  ))
  vm <- numeric()
  vs <- numeric()
  for (centro in centros) {
    a <- max(1L,centro-25L)
    b <- min(nr,centro+25L)
    nl <- b-a+1L
    x <- ler_matriz(r,a,nl)/escala
    g <- sobel(x)
    ok <- g$crista &
    is.finite(g$mag) &
    is.finite(g$score) &
    g$mag > 0
    m <- g$mag[ok]
    s <- g$score[ok]
    if (length(m) > 2500L) {
      idx <- sample.int(length(m),2500L)
      m <- m[idx]
      s <- s[idx]
    }
    vm <- c(vm,m)
    vs <- c(vs,s)
  }
  if (length(vm) < 100L) {
    stop("Amostra insuficiente para calibrar Sobel.")
  }
  list(
  mag_fraco = quantil(vm,CFG$q_mag_fraco),
  mag_forte = quantil(vm,CFG$q_mag_forte),
  score_fraco = max(
  CFG$score_fraco_min,
  quantil(vs,CFG$q_score_fraco)
  ),
  score_forte = max(
  CFG$score_forte_min,
  quantil(vs,CFG$q_score_forte)
  ),
  n = length(vm)
  )
}

# Deteccao de descontinuidades

detectar_linhas <- function(x, lim, detalhes = FALSE) {
  g <- sobel(x)
  fraco <- g$crista &
  g$mag >= lim$mag_fraco &
  g$score >= lim$score_fraco
  forte <- fraco &
  g$mag >= lim$mag_forte &
  g$score >= lim$score_forte
  fraco[is.na(fraco)] <- FALSE
  forte[is.na(forte)] <- FALSE
  conectado <- forte
  for (i in seq_len(CFG$histerese)) {
    novo <- conectado | (
    fraco & vizinhos(conectado)
    )
    if (identical(novo,conectado)) break
    conectado <- novo
  }
  sup <- contar(conectado,3L)
  ali <- suporte_direcional(conectado)
  principal <- conectado &
  sup >= CFG$suporte_principal &
  ali >= CFG$direcao_principal
  secundaria <- conectado &
  sup >= CFG$suporte_secundario &
  ali >= CFG$direcao_secundaria &
  !principal
  principal[is.na(principal)] <- FALSE
  secundaria[is.na(secundaria)] <- FALSE
  if (CFG$conectar) {
    direta <- principal | secundaria
    ponte <- matrix(
    FALSE,nrow(x),ncol(x)
    )
    for (d in list(
    c(0L,1L),c(1L,0L),
    c(1L,1L),c(1L,-1L)
    )) {
      ponte <- ponte | (
      deslocar(direta,d[1],d[2],FALSE) &
      deslocar(direta,-d[1],-d[2],FALSE)
      )
    }
    ponte <- ponte &
    !direta &
    g$seguro &
    is.finite(g$mag) &
    is.finite(g$score) &
    g$mag >= 0.70*lim$mag_fraco &
    g$score >= 0.70*lim$score_fraco
    ponte[is.na(ponte)] <- FALSE
    secundaria <- secundaria | ponte
  }
  out <- matrix(0L,nrow(x),ncol(x))
  out[secundaria] <- 2L
  out[principal] <- 1L
  out[!is.finite(x)] <- NA_integer_
  if (detalhes) return(list(classes=out,mag=g$mag,score=g$score))
  out
}

# Processamento Sobel por blocos

processar_sobel <- function(r,bio,destino) {
  esc <- escala_temperatura(r,bio)
  terra::readStart(r) # readValues somente depois de abrir a leitura
  leitura_aberta <- TRUE
  out <- terra::rast(r)
  escrita_aberta <- FALSE
  on.exit({
    if(escrita_aberta) try(terra::writeStop(out),silent=TRUE)
    if(leitura_aberta) try(terra::readStop(r),silent=TRUE)
  },add=TRUE)
  lim <- calibrar_linhas(r,esc)
  terra::writeStart(out,filename=destino,overwrite=TRUE,
  datatype="INT1U",gdal="COMPRESS=LZW")
  escrita_aberta <- TRUE
  passos <- seq.int(1L,terra::nrow(r),by=CFG$bloco)
  for(k in seq_along(passos)) {
    ini <- passos[k]; n <- min(CFG$bloco,terra::nrow(r)-ini+1L)
    a <- max(1L,ini-CFG$halo)
    b <- min(terra::nrow(r),ini+n-1L+CFG$halo)
    x <- ler_matriz(r,a,b-a+1L)/esc
    z <- detectar_linhas(x,lim)
    ids <- seq.int(ini-a+1L,length.out=n)
    terra::writeValues(out,as.vector(t(z[ids,,drop=FALSE])),start=ini,nrows=n)
    if(k%%10L==0L || k==length(passos))
    logar(bio," | Sobel original ",k,"/",length(passos))
  }
  terra::writeStop(out); escrita_aberta <- FALSE
  terra::readStop(r); leitura_aberta <- FALSE
  list(raster=terra::rast(destino),limiares=lim)
}
perfil_degrau <- function(x,g) {
  nr <- nrow(x); nc <- ncol(x)
  ax <- abs(g$gx); ay <- abs(g$gy)
  orient <- ifelse(ax>=2.414*ay,1L,
  ifelse(ay>=2.414*ax,2L,
  ifelse(g$gx*g$gy>=0,3L,4L)))
  direcoes <- list(c(0L,1L),c(1L,0L),c(1L,1L),c(1L,-1L))
  salto <- matrix(NA_real_,nr,nc)
  intra <- matrix(NA_real_,nr,nc)
  for (j in seq_along(direcoes)) {
    dr <- direcoes[[j]][1]; dc <- direcoes[[j]][2]
    ap1 <- deslocar(x,dr,dc); ap2 <- deslocar(x,2L*dr,2L*dc)
    am1 <- deslocar(x,-dr,-dc); am2 <- deslocar(x,-2L*dr,-2L*dc)
    p <- abs((ap1+ap2-am1-am2)/2)
    t <- (abs(ap1-ap2)+abs(am1-am2))/2
    escolha <- !is.na(orient) & orient==j
    salto[escolha] <- p[escolha]
    intra[escolha] <- t[escolha]
  }
  list(salto=salto,intra=intra,orient=orient)
}
amplitude3 <- function(x) {
  mn <- x; mx <- x; valido <- is.finite(x)
  for(d in DIRECOES) {
    y <- deslocar(x,d[1],d[2])
    mn <- pmin(mn,y); mx <- pmax(mx,y)
    valido <- valido & is.finite(y)
  }
  z <- mx-mn
  z[!valido] <- NA_real_
  z
}

# Mascara C4

produzir_c4 <- function(r,bruto,bio,base,lim,destino) {
  escala <- escala_temperatura(r,bio)
  minimo <- unname(CFG$salto_fraco[bio])
  forte_min <- unname(CFG$salto_forte[bio])
  if (length(minimo)!=1L || length(forte_min)!=1L ||
  !is.finite(minimo) || !is.finite(forte_min))
  stop("Limiares C4 ausentes: ",bio)
  entrada <- list(r,bruto)
  out <- terra::rast(r)
  leitura_aberta <- 0L
  escrita_aberta <- FALSE
  on.exit({
    if (escrita_aberta) try(terra::writeStop(out),silent=TRUE)
    if (leitura_aberta>0L)
    for (j in seq.int(leitura_aberta,1L))
    try(terra::readStop(entrada[[j]]),silent=TRUE)
  },add=TRUE)
  for (j in seq_along(entrada)) {
    terra::readStart(entrada[[j]])
    leitura_aberta <- j
  }
  terra::writeStart(out,filename=destino,overwrite=TRUE,datatype="INT1U",
  gdal="COMPRESS=LZW")
  escrita_aberta <- TRUE
  nr <- terra::nrow(r)
  inicio <- seq.int(1L,nr,by=CFG$bloco)
  n_c4 <- 0
  for (k in seq_along(inicio)) {
    ini <- inicio[k]; n <- min(CFG$bloco,nr-ini+1L)
    a <- max(1L,ini-CFG$halo)
    b <- min(nr,ini+n-1L+CFG$halo)
    x <- ler_matriz(r,a,b-a+1L)/escala
    cl <- ler_matriz(bruto,a,b-a+1L)
    g <- sobel(x)
    p <- perfil_degrau(x,g)
    amp <- amplitude3(x)
    evidencia <- is.finite(p$salto) & is.finite(p$intra) & is.finite(amp)
    razao <- p$salto/(p$intra+minimo*0.10)
    candidatos <- is.finite(cl) & cl %in% c(1,2)
    candidatos[is.na(candidatos)] <- FALSE
    forte <- candidatos & evidencia & g$crista &
    amp>=forte_min & p$salto>=forte_min & razao>=CFG$razao_forte
    moderado <- candidatos & evidencia & g$crista &
    amp>=minimo & p$salto>=minimo & razao>=CFG$razao_fraca
    forte[is.na(forte)] <- FALSE
    moderado[is.na(moderado)] <- FALSE
    suporte <- suporte_direcional(candidatos)
    c5_ref <- forte | (moderado & suporte>=CFG$suporte_referencia_ponte)
    c4_sem_ponte <- forte | (moderado & suporte>=CFG$suporte_c4)
    nv <- contar(c5_ref,1L)-as.integer(c5_ref)
    pontes <- matrix(FALSE,nrow(x),ncol(x))
    for (d in list(c(0L,1L),c(1L,0L),c(1L,1L),c(1L,-1L))) {
      dr <- d[1]; dc <- d[2]
      frente <- deslocar(c5_ref,dr,dc,FALSE)
      tras <- deslocar(c5_ref,-dr,-dc,FALSE)
      cond <- frente & tras & nv==2L & !c5_ref &
      is.finite(x) & g$seguro & evidencia &
      amp>=minimo*CFG$ponte_salto_frac &
      p$salto>=minimo*CFG$ponte_salto_frac &
      razao>=CFG$razao_fraca &
      g$mag>=CFG$ponte_mag_frac*lim$mag_fraco
      ortho <- abs(g$gy*dr+g$gx*dc)/
      (pmax(g$mag,1e-10)*sqrt(dr^2+dc^2))
      cond <- cond & is.finite(ortho) & ortho<=0.50
      cond[is.na(cond)] <- FALSE
      pontes <- pontes | cond
    }
    c4 <- c4_sem_ponte | pontes
    c4[is.na(c4)] <- FALSE
    y <- matrix(0L,nrow(x),ncol(x))
    y[c4] <- 1L
    y[!is.finite(x)] <- NA_integer_
    ii <- seq.int(ini-a+1L,length.out=n)
    terra::writeValues(out,as.vector(t(y[ii,,drop=FALSE])),start=ini,nrows=n)
    n_c4 <- n_c4 + sum(c4[ii,,drop=FALSE])
    if (k%%10L==0L || k==length(inicio))
    logar(base," | C4 ",k,"/",length(inicio))
  }
  terra::writeStop(out); escrita_aberta <- FALSE
  for (j in seq.int(leitura_aberta,1L)) terra::readStop(entrada[[j]])
  leitura_aberta <- 0L
  logar(base," | celulas C4 originais: ",n_c4)
  terra::rast(destino)
}

# Deteccao de platos V7

detectar_platos_v7 <- function(r,area,bio,destino,base) {
  q <- unname(CFG$quantum[bio])
  if(length(q)!=1L || !is.finite(q)) stop("Quantum indefinido: ",bio)
  esc <- escala_temperatura(r,bio)
  x <- r/esc
  logar(base," | amplitude 3x3...")
  max3 <- terra::focal(x,w=3,fun="max",na.rm=TRUE)
  min3 <- terra::focal(x,w=3,fun="min",na.rm=TRUE)
  valido <- terra::ifel(is.na(x),0,1)
  completo <- terra::focal(valido,w=3,fun="sum",na.rm=TRUE)==9
  nucleo <- terra::ifel(completo & (max3-min3)<q/2,1,NA)
  rm(max3,min3,completo,valido)
  logar(base," | agrupamento de nucleos v7 (terra::patches)...")
  ids <- terra::patches(nucleo,directions=8,
  filename=file.path(DIR$cache,paste0(base,"_IDs_platos.tif")),overwrite=TRUE)
  tab <- terra::zonal(area,ids,fun="sum",na.rm=TRUE)
  ftab <- file.path(DIR$tabelas,paste0(base,"_Regioes_Platos.csv"))
  if(is.null(tab) || !nrow(tab)) {
    write.csv(data.frame(ID=integer(),Area_km2=numeric(),Aceito=logical()),
    ftab,row.names=FALSE)
    salvar(terra::ifel(is.na(r),NA,0),destino)
    return(list(raster=terra::rast(destino),diagnostico=data.frame(
    Manchas_Candidatas=0,Manchas_Aceitas=0,Quantum=q)))
  }
  tab <- as.data.frame(tab)[,1:2,drop=FALSE]
  names(tab) <- c("ID","Area_km2")
  tab$Aceito <- is.finite(tab$Area_km2) &
  tab$Area_km2>=CFG$area_min_plato_km2
  tab$Excluido_Muito_Seco <- FALSE
  if(bio=="BIO14" && CFG$excluir_bio14_muito_seco && any(tab$Aceito)) {
    medias <- terra::zonal(x,ids,fun="mean",na.rm=TRUE)
    if(!is.null(medias) && nrow(medias)) {
      mm <- as.numeric(medias[,2][match(tab$ID,medias[,1])])
      tab$Media_mm <- mm
      tab$Excluido_Muito_Seco <- tab$Aceito & is.finite(mm) &
      mm<=CFG$bio14_seco_mm
      tab$Aceito[tab$Excluido_Muito_Seco] <- FALSE
    }
  }
  write.csv(tab,ftab,row.names=FALSE)
  bons <- tab$ID[tab$Aceito]
  if(length(bons)) {
    mascara <- terra::ifel(ids %in% bons,1,0)
    mascara <- terra::ifel(is.na(r),NA,mascara)
  } else {
    mascara <- terra::ifel(is.na(r),NA,0)
  }
  salvar(mascara,destino)
  list(raster=terra::rast(destino),diagnostico=data.frame(
  Manchas_Candidatas=nrow(tab),Manchas_Aceitas=length(bons),Quantum=q))
}

# Validacao das mascaras

contar_um <- function(x) {
  z <- terra::global(terra::ifel(x==1,1,0),"sum",na.rm=TRUE)
  if (is.null(z) || !nrow(z) || !is.finite(z[1,1])) return(0)
  as.numeric(z[1,1])
}
validar_mesma_mascara <- function(r,c4,risco,base) {
  if(!terra::compareGeom(r,c4,stopOnError=FALSE) ||
  !terra::compareGeom(r,risco,stopOnError=FALSE))
  stop("Grades diferentes em ",base)
  fora <- terra::ifel(c4==1 & risco!=1,1,0)
  nfora <- contar_um(fora)
  if(!is.finite(nfora) || nfora!=0)
  stop("INCONSISTENCIA: ",nfora," pixels C4 fora do buffer em ",base)
  invalidos <- terra::ifel(is.na(r) & (c4==1 | risco==1),1,0)
  ninval <- contar_um(invalidos)
  if(!is.finite(ninval) || ninval!=0)
  stop("INCONSISTENCIA: pixels de risco/deteccao em area invalida em ",base)
  invisible(TRUE)
}

# Buffer de risco

criar_risco <- function(r,c4,base,saida) {
  if(!terra::is.lonlat(r,warn=FALSE))
  stop("Este projeto espera CRS longitude/latitude; buffer em metros")
  if(terra::global(terra::ifel(c4==1,1,0),"sum",na.rm=TRUE)[1,1]==0)
  return(terra::ifel(is.na(r),NA,0,filename=saida,overwrite=TRUE,
  wopt=list(gdal="COMPRESS=LZW")))
  sementes <- terra::ifel(c4==1,1,NA)
  tmp <- file.path(DIR$temp,paste0(base,"_buffer10_tmp.tif"))
  buff <- terra::buffer(sementes,width=CFG$buffer_risco_km*1000,
  background=0,filename=tmp,overwrite=TRUE)
  terra::ifel(is.na(r),NA,
  terra::ifel((buff==1) | (c4==1),1,0),
  filename=saida,overwrite=TRUE,
  wopt=list(gdal="COMPRESS=LZW"))
  terra::rast(saida)
}

# Quantificacao e mapas

area_km2 <- function(mask) {
  presente <- terra::ifel(mask,1,NA)
  a <- terra::expanse(presente,unit="km")
  if(is.null(a) || !nrow(a) || !is.finite(a$area[1])) return(0)
  as.numeric(a$area[1])
}
pixels_um <- function(x) {
  f <- terra::freq(x)
  if(is.null(f) || !nrow(f)) return(0)
  sum(f$count[f$value==1],na.rm=TRUE)
}
quantificar <- function(r,c4,risco,bioma,bio,tipo,
manchas_aceitas=NA_integer_,quantum=NA_real_) {
  total <- area_km2(!is.na(r))
  area_detectada <- area_km2(c4==1)
  area_risco <- if(tipo=="Linha") area_km2(risco==1) else NA_real_
  if(!is.finite(total) || total<=0) stop("Area total invalida: ",bioma,"/",bio)
  if(area_detectada>total+1 || (tipo=="Linha" && area_risco+1<area_detectada))
  stop("Areas incoerentes: ",bioma,"/",bio)
  pct <- 100*area_detectada/total
  n_pixels <- contar_um(c4)
  data.frame(
  Variavel=bio,Bioma=bioma,Tipo=tipo,Status="OK",
  Metodo=if(tipo=="Linha") "C4_sem_filtro" else "Plato_V7_sem_buffer",
  Area_Total_km2=total,
  Area_Detectada_km2=area_detectada,
  Pct_Detectada=pct,
  Area_Bruta_km2=area_detectada,
  Area_Original_km2=area_detectada,
  Area_Risco_10km_km2=area_risco,
  Area_Adicional_Risco_km2=if(tipo=="Linha") max(0,area_risco-area_detectada) else NA_real_,
  Pct_Bruta=pct,
  Pct_Original=pct,
  Pct_Risco_10km=if(tipo=="Linha") 100*area_risco/total else NA_real_,
  Expansao_Relativa_pct=if(tipo=="Linha" && area_detectada>0)
  100*(area_risco-area_detectada)/area_detectada else NA_real_,
  Area_Removida_Filtro_km2=0,
  Pixels_Brutos=n_pixels,
  Pixels_Originais=n_pixels,
  Grupos_Isolados_Removidos=0,
  Pixels_Removidos=0,
  Regioes_Plato_Aceitas=manchas_aceitas,
  Quantum_Plato=quantum,
  Buffer_km=if(tipo=="Linha") CFG$buffer_risco_km else NA_real_,
  C4_Contido_No_Risco=if(tipo=="Linha") TRUE else NA,
  stringsAsFactors=FALSE
  )
}
preparar_mapa <- function(r,m) {
  fator <- max(1L,ceiling(sqrt(terra::ncell(r)/CFG$max_celulas_png)))
  fundo <- if(fator>1L) terra::aggregate(r,fact=fator,fun="mean",na.rm=TRUE) else r
  raster_marca <- terra::ifel(m==1,1,0)
  if(fator>1L) raster_marca <- terra::aggregate(raster_marca,fact=fator,
  fun="max",na.rm=TRUE)
  marca <- terra::ifel(is.na(fundo),NA,terra::ifel(raster_marca>0,1,NA))
  list(fundo=fundo,marca=marca)
}
desenhar_mapa <- function(fundo,marcas,cores,titulo="",legenda=NULL) {
  terra::plot(fundo,col=gray.colors(140,start=.95,end=.20),
  legend=FALSE,axes=FALSE,box=FALSE,smooth=FALSE,
  maxcell=terra::ncell(fundo),main=titulo)
  for(i in seq_along(marcas)) {
    mk <- marcas[[i]]
    if(pixels_um(mk)>0) terra::plot(mk,col=cores[i],add=TRUE,
    legend=FALSE,axes=FALSE,colNA=NA,smooth=FALSE,
    breaks=c(.5,1.5),maxcell=terra::ncell(mk))
  }
  if(length(legenda)) graphics::legend("bottomleft",legend=legenda,
  fill=cores,cex=.75,bg="white")
}
exportar_mapas <- function(r,mascara,risco,base,tipo) {
  raw <- preparar_mapa(r,mascara)
  zona_buffer <- if(tipo=="Linha")
  terra::ifel(risco==1 & mascara!=1,1,0) else NULL
  buf <- if(tipo=="Linha") preparar_mapa(r,zona_buffer) else NULL
  fontes_mapa <- c(terra::sources(mascara),
  if(!is.null(risco)) terra::sources(risco))
  fontes_mapa <- fontes_mapa[file.exists(fontes_mapa)]
  ultima_analise <- if(length(fontes_mapa))
  max(as.numeric(file.info(fontes_mapa)$mtime),na.rm=TRUE) else Inf
  for(sem_legenda in c(FALSE,TRUE)) {
    pasta <- if(sem_legenda) DIR$sem_legenda else DIR$mapas
    for(modo in if(tipo=="Linha") c("original","risco_10km") else "platos") {
      arquivo <- file.path(pasta,paste0(base,"_",modo,".png"))
      if(file.exists(arquivo) && !CFG$refazer_mapas &&
      as.numeric(file.info(arquivo)$mtime) >= ultima_analise) next
      grDevices::png(arquivo,width=1600,height=1400,res=160,bg="white")
      tryCatch({
        graphics::par(mar=if(sem_legenda) c(0,0,0,0) else c(0,0,3,0))
        if(tipo=="Plato") {
          desenhar_mapa(raw$fundo,list(raw$marca),CFG$cor_platos,
          if(sem_legenda) "" else paste(base,"- platos"),
          if(sem_legenda) NULL else "Regioes homogeneas")
        } else if(modo=="original") {
          desenhar_mapa(raw$fundo,list(raw$marca),CFG$cor_linhas,
          if(sem_legenda) "" else paste(base,"- C4 original"),
          if(sem_legenda) NULL else "C4 original")
        } else {
          desenhar_mapa(raw$fundo,list(buf$marca,raw$marca),
          c(grDevices::adjustcolor(CFG$cor_linhas,alpha.f=CFG$transparencia_risco),
          CFG$cor_linhas),
          if(sem_legenda) "" else paste(base,"- area de risco 10 km"),
          if(sem_legenda) NULL else c("Risco 10 km","C4 original"))
        }
      },finally={grDevices::dev.off()})
    }
  }
}

# Execucao da analise

if(CFG$modo=="piloto") {
  TAREFAS<-CFG$piloto
} else {
  TAREFAS<-expand.grid(Variavel=c(CFG$platos,CFG$linhas),
  Bioma=CFG$biomas,stringsAsFactors=FALSE)
}
if(anyDuplicated(TAREFAS[,c("Bioma","Variavel")])) stop("Tarefas duplicadas")
indice_entrada <- data.frame(Variavel=TAREFAS$Variavel,Bioma=TAREFAS$Bioma,
Arquivo=NA_character_,Status="PENDENTE",stringsAsFactors=FALSE)
for(i in seq_len(nrow(TAREFAS))) {
  tryCatch({
    indice_entrada$Arquivo[i]<-localizar(TAREFAS$Variavel[i],TAREFAS$Bioma[i])
    indice_entrada$Status[i]<-"OK"
  },error=function(e) indice_entrada$Status[i]<<-conditionMessage(e))
}
write.csv(indice_entrada,file.path(DIR$tabelas,"entradas.csv"),row.names=FALSE)
if(any(indice_entrada$Status!="OK")) logar("ATENCAO: entradas ausentes. Consulte tabelas/entradas.csv")
resumos <- list(); falhas <- list(); tempos <- list()
parametros_linha <- CFG[c("q_mag_fraco","q_mag_forte","q_score_fraco",
"q_score_forte","score_fraco_min","score_forte_min","histerese",
"suporte_principal","direcao_principal","suporte_secundario",
"direcao_secundaria","conectar","salto_forte","salto_fraco",
"razao_forte","razao_fraca","suporte_c4","suporte_referencia_ponte",
"ponte_salto_frac","ponte_mag_frac","bloco","halo")]
for(i in seq_len(nrow(TAREFAS))) {
  bioma <- TAREFAS$Bioma[i]; bio <- TAREFAS$Variavel[i]
  base <- paste0(bioma,"_",bio)
  tipo <- if(bio %in% CFG$linhas) "Linha" else "Plato"
  inicio_tarefa <- Sys.time(); ok <- FALSE
  logar("INICIO [",i,"/",nrow(TAREFAS),"] ",base," | ",tipo)
  tryCatch({
    origem <- localizar(bio,bioma)
    r0 <- terra::rast(origem)
    if(terra::nlyr(r0)!=1L || !nzchar(terra::crs(r0))) stop("Raster invalido")
    if(!terra::is.lonlat(r0,warn=FALSE)) stop("Entrada deve estar em lon/lat WorldClim")
    r <- preparar_agua(r0,bio,bioma,origem)
    prefix <- file.path(DIR$rasters,base)
    f_c4 <- paste0(prefix,"_C4.tif")
    f_risco <- paste0(prefix,"_risco_10km.tif")
    f_plato <- paste0(prefix,"_platos.tif")
    f_tabela <- file.path(DIR$tabelas,paste0(base,"_areas.csv"))
    sig_fonte <- list(versao=VERSAO,origem=assinar(origem),
    hidrografia=if(CFG$usar_agua) assinar(CFG$agua) else NULL)
    if(tipo=="Linha") {
      sig_c4 <- list(fonte=sig_fonte,criterios=parametros_linha)
      meta_c4 <- paste0(f_c4,".rds")
      if(cache_ok(f_c4,meta_c4,sig_c4,r)) {
        c4 <- terra::rast(f_c4)
        logar(base," | C4 definitivo em cache (sem filtro)")
      } else {
        f_sobel <- file.path(DIR$cache,paste0(base,"_sobel.tif"))
        logar(base," | Sobel original...")
        ss <- processar_sobel(r,bio,f_sobel)
        logar(base," | perfil C4 sem filtro...")
        c4 <- produzir_c4(r,ss$raster,bio,base,ss$limiares,f_c4)
        write.csv(data.frame(Parametro=names(ss$limiares),
        Valor=as.numeric(unlist(ss$limiares))),
        file.path(DIR$tabelas,paste0(base,"_limiares.csv")),row.names=FALSE)
        saveRDS(sig_c4,meta_c4)
      }
      meta_risco <- paste0(f_risco,".rds")
      sig_risco <- list(arquivo_c4=assinar(f_c4),distancia_km=CFG$buffer_risco_km)
      if(cache_ok(f_risco,meta_risco,sig_risco,r)) {
        risco <- terra::rast(f_risco)
        logar(base," | risco em cache (origem unica: C4)")
      } else {
        logar(base," | buffer de risco de 10 km a partir do mesmo C4...")
        risco <- criar_risco(r,c4,base,f_risco)
        saveRDS(sig_risco,meta_risco)
      }
      validar_mesma_mascara(r,c4,risco,base)
      res <- quantificar(r,c4,risco,bioma,bio,tipo)
      exportar_mapas(r,c4,risco,base,tipo)
    } else {
      meta_plato <- paste0(f_plato,".rds")
      sig_plato <- list(fonte=sig_fonte,quantum=CFG$quantum,
      area_min=CFG$area_min_plato_km2,
      seco=CFG$excluir_bio14_muito_seco,limiar=CFG$bio14_seco_mm)
      arquivo_diag <- file.path(DIR$tabelas,paste0(base,"_diagnostico_platos.csv"))
      if(cache_ok(f_plato,meta_plato,sig_plato,r) && file.exists(arquivo_diag)) {
        plato <- terra::rast(f_plato)
        diag <- read.csv(arquivo_diag)
        logar(base," | plato V7 em cache")
      } else {
        area <- terra::cellSize(r,unit="km",mask=FALSE)
        det <- detectar_platos_v7(r,area,bio,f_plato,base)
        plato <- det$raster
        diag <- det$diagnostico
        write.csv(diag,arquivo_diag,row.names=FALSE)
        saveRDS(sig_plato,meta_plato)
      }
      res <- quantificar(r,plato,NULL,bioma,bio,tipo,
      manchas_aceitas=diag$Manchas_Aceitas[1],quantum=diag$Quantum[1])
      exportar_mapas(r,plato,NULL,base,tipo)
    }
    write.csv(res,f_tabela,row.names=FALSE)
    resumos[[base]] <- res
    ok <- TRUE
    logar("OK ",base," | deteccao=",round(res$Pct_Detectada,5),
    "% | risco=",if(tipo=="Linha") round(res$Pct_Risco_10km,5) else "NA","%")
  },error=function(e) {
    logar("ERRO ",base,": ",conditionMessage(e))
    falhas[[base]] <<- data.frame(Variavel=bio,Bioma=bioma,Erro=conditionMessage(e))
  })
  tempos[[base]] <- data.frame(Bioma=bioma,Variavel=bio,
  Minutos=as.numeric(difftime(Sys.time(),inicio_tarefa,units="mins")),
  Status=if(ok) "OK" else "ERRO")
  if(length(resumos)) write.csv(do.call(rbind,resumos),
  file.path(DIR$tabelas,"resultados_parciais.csv"),row.names=FALSE)
  if(length(falhas)) write.csv(do.call(rbind,falhas),
  file.path(DIR$tabelas,"erros.csv"),row.names=FALSE)
  write.csv(do.call(rbind,tempos),
  file.path(DIR$tabelas,"tempos.csv"),row.names=FALSE)
  gc(FALSE)
}

# Resultados consolidados

colunas <- c("Variavel","Bioma","Tipo","Status","Metodo", "Area_Total_km2",
"Area_Detectada_km2","Pct_Detectada","Area_Bruta_km2",
"Area_Original_km2","Area_Risco_10km_km2","Area_Adicional_Risco_km2",
"Pct_Bruta","Pct_Original","Pct_Risco_10km","Expansao_Relativa_pct",
"Area_Removida_Filtro_km2","Pixels_Brutos","Pixels_Originais",
"Grupos_Isolados_Removidos","Pixels_Removidos","Regioes_Plato_Aceitas",
"Quantum_Plato","Buffer_km","C4_Contido_No_Risco")
saida <- lapply(seq_len(nrow(TAREFAS)),function(i) {
  bb <- TAREFAS$Bioma[i]; vv <- TAREFAS$Variavel[i]
  z <- resumos[[paste0(bb,"_",vv)]]
  if(!is.null(z)) return(z)
  x <- as.list(stats::setNames(rep(NA,length(colunas)),colunas))
  x$Variavel <- vv; x$Bioma <- bb
  x$Tipo <- if(vv %in% CFG$linhas) "Linha" else "Plato"
  x$Status <- "ERRO_OU_AUSENTE"
  as.data.frame(x,stringsAsFactors=FALSE)
})
final <- do.call(rbind,saida)
rownames(final) <- NULL
final$Variavel <- factor(final$Variavel,levels=c(CFG$platos,CFG$linhas))
final$Bioma <- factor(final$Bioma,levels=CFG$biomas)
final <- final[order(final$Variavel,final$Bioma),]
final$Variavel <- as.character(final$Variavel)
final$Bioma <- as.character(final$Bioma)
if(nrow(final)!=nrow(TAREFAS) || anyDuplicated(final[,c("Bioma","Variavel")]))
stop("Resumo inconsistente: combinacoes ausentes ou duplicadas")
matriz <- reshape(final[,c("Variavel","Bioma","Pct_Detectada")],
idvar="Variavel",timevar="Bioma",direction="wide")
names(matriz) <- sub("^Pct_Detectada\\.","",names(matriz))
for(bb in setdiff(CFG$biomas,names(matriz))) matriz[[bb]] <- NA_real_
matriz <- matriz[,c("Variavel",CFG$biomas),drop=FALSE]
violino <- final[,c("Variavel","Bioma","Tipo","Status","Metodo",
"Pct_Detectada","Pct_Risco_10km","Area_Detectada_km2","Area_Total_km2")]
linhas_final <- final[final$Tipo=="Linha",,drop=FALSE]
platos_final <- final[final$Tipo=="Plato",,drop=FALSE]
linhas_ok <- linhas_final[linhas_final$Status=="OK",,drop=FALSE]
if(nrow(linhas_ok)) {
  if(any(abs(linhas_ok$Area_Bruta_km2-linhas_ok$Area_Original_km2)>1e-8) ||
  any(abs(linhas_ok$Area_Detectada_km2-linhas_ok$Area_Original_km2)>1e-8) ||
  any(abs(linhas_ok$Pct_Detectada-linhas_ok$Pct_Original)>1e-8) ||
  any(linhas_ok$C4_Contido_No_Risco!=TRUE) ||
  any(linhas_ok$Area_Risco_10km_km2+1 < linhas_ok$Area_Detectada_km2))
  stop("AUDITORIA FALHOU: a area C4 nao corresponde aos resultados oficiais.")
}
completo <- (nrow(final)==48L && all(final$Status=="OK"))
if(completo) {
  write.csv(final,file.path(DIR$tabelas,"resumo_geral.csv"),row.names=FALSE,na="")
  write.csv2(final,file.path(DIR$tabelas,"resumo_excel_br.csv"),row.names=FALSE,na="")
  write.csv(matriz,file.path(DIR$tabelas,"matriz_percentuais.csv"),row.names=FALSE,na="")
  write.csv(violino,file.path(DIR$tabelas,"dados_para_violino.csv"),row.names=FALSE,na="")
  write.csv(linhas_final,file.path(DIR$tabelas,"resumo_descontinuidades.csv"),row.names=FALSE,na="")
  write.csv(platos_final,file.path(DIR$tabelas,"resumo_platos.csv"),row.names=FALSE,na="")
  if(CFG$exportar_excel) {
    writexl::write_xlsx(list(Resumo_48=final,Descontinuidades_24=linhas_final,
    Platos_24=platos_final,Matriz_pct=matriz,Dados_violinos=violino),
    file.path(DIR$tabelas,"resultados_artigo.xlsx"))
  }
  unlink(file.path(DIR$tabelas,"ATENCAO_resultado_INCOMPLETO.csv"))
  unlink(file.path(DIR$tabelas,"erros.csv"))
  writeLines(c(
  "RESULTADOS COMPLETOS: 48/48 combinacoes validas.",
  "LINHAS: mascara unica *_C4.tif (C4 original SEM filtro de 10/21 pixels).",
  "BUFFER: sempre criado a partir de *_C4.tif e contem todos os pixels C4.",
  "% detectado: sem buffer. % risco: buffer 10 km separado.",
  "PLATOS: nucleo V7, sem buffer e sem expansao.",
  "Todos os CSV e Excel oficiais desta execucao estao em tabelas/.",
  paste0("Pasta: ",DIR$base)),
  file.path(DIR$tabelas,"VALIDACAO_FINAL.txt"))
} else {
  if(CFG$modo=="piloto") {
    write.csv(final,file.path(DIR$tabelas,"resumo_piloto.csv"),row.names=FALSE,na="")
    logar("MODO PILOTO: resultados exploratorios em tabelas/resumo_piloto.csv")
  }
  for(nm in c("resumo_geral.csv","resumo_excel_br.csv",
  "matriz_percentuais.csv","dados_para_violino.csv",
  "resumo_descontinuidades.csv","resumo_platos.csv",
  "resultados_artigo.xlsx"))
  unlink(file.path(DIR$tabelas,nm))
  write.csv(final,file.path(DIR$tabelas,"ATENCAO_resultado_INCOMPLETO.csv"),row.names=FALSE,na="")
  writeLines(c("RESULTADOS INCOMPLETOS: NAO UTILIZAR PARA RESULTADOS DO ARTIGO.",
  paste0("Concluidos: ",sum(final$Status=="OK")," de ",nrow(TAREFAS)),
  "Corrija os erros listados em erros.csv e reexecute o mesmo script.",
  "O cache reutilizara automaticamente os rasters validos."),
  file.path(DIR$tabelas,"VALIDACAO_FINAL.txt"))
  if(CFG$modo=="final")
  warning("Analise incompleta. NAO utilizar resultados para artigo antes de 48/48 OK.")
}
saveRDS(CFG,file.path(DIR$tabelas,"configuracao.rds"))
writeLines(capture.output(sessionInfo()),file.path(DIR$tabelas,"versoes_R.txt"))
logar("FIM: ",sum(final$Status=="OK"),"/",nrow(TAREFAS),
" tarefas. Oficial=",completo,". Saida: ",DIR$base)
