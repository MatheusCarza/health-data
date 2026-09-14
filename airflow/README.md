# Orquestração do Health Data com Apache Airflow

Esta pasta contém a primeira versão executável da orquestração do pipeline.
Ela foi desenhada para rodar com Docker Compose tanto no ambiente local quanto
em uma única VM Linux no OCI Compute.

## Escopo da primeira versão

A DAG histórica `health_data_pipeline` automatiza o fluxo reprodutível da
amostra:

1. valida o ambiente;
2. executa em paralelo os coletores SIH/SUS, CNES e IBGE;
3. valida esquema, volume, competências, chaves e campos obrigatórios;
4. gera `sql/dml_health_data.sql`;
5. valida a estrutura mínima do script de carga.

Ela permanece sem agenda e não escreve no Oracle. A DAG
`health_data_incremental` implementa o fluxo mensal validado: coleta uma
competência, atualiza CNES e IBGE, valida os dados, publica as três fontes no
Bronze, carrega as quatro stagings, executa o pacote Oracle e reconcilia a
contagem. Ela nasce pausada e possui agenda mensal para o dia 15 às 06:00 no
fuso de São Paulo. O primeiro disparo manual para `SP/2024/12` validou o caminho
idempotente `REUTILIZADO`, com 225.756 fatos reconciliados e nenhuma duplicação.

Disparos manuais usam os Params `uf`, `ano` e `mes`. Disparos agendados buscam
no controle Oracle o mês seguinte à última carga bem-sucedida. A variável
`HEALTH_DATA_AUTO_MAX_COMPETENCIA`, no formato `YYYYMM`, funciona como trava de
escopo; seu padrão `202412` impede que o scheduler carregue 2025 ou 2026 antes
da validação das novas fontes e da autorização de expansão temporal.

Os três coletores aceitam parâmetros pela linha de comando: UF, ano e intervalo
mensal no SIH; UF no CNES; e UF, ano e URL oficial no IBGE. A DAG incremental
expõe `uf`, `ano` e `mes` para disparos manuais. A DAG histórica continua ligada
à geração da amostra anual e não deve receber um recorte mensal.

O módulo `src/health_data_pipeline/object_storage.py` publica no bucket
configurado com partições sob `bronze/`. Na VM ele usa Instance Principal; no
ambiente local, usa a configuração OCI montada como volume somente leitura.
Tamanho e SHA-256 impedem que uma repetição sobrescreva conteúdo divergente.

O arquivo `sql/etl_incremental.sql` define controle de execução, stagings e o
pacote Oracle que faz `MERGE` das dimensões e substitui somente uma competência
da fato dentro da mesma transação. O backfill integral de `SP/2024` validou o
pacote e o carregador Python em 12 competências e 2.855.539 fatos.
`DIM_MUNICIPIO_POPULACAO` mantém as estimativas populacionais por município e
ano; a coluna `DIM_MUNICIPIO.POPULACAO_2024` permanece apenas para
compatibilidade com componentes ainda não migrados do APEX.

## Execução local

Pré-requisitos: Docker com Compose v2 e pelo menos 4 GB de memória disponível.

```bash
cd airflow
./scripts/init-env.sh
```

O script gera senhas e chaves aleatórias em `.env`, com permissão restrita. O
arquivo é ignorado pelo Git. Para consultar apenas a senha inicial do usuário
local, execute `grep AIRFLOW_ADMIN_PASSWORD .env` no terminal; não compartilhe
nem registre esse valor em capturas.

Depois:

```bash
docker compose build
docker compose up airflow-init
docker compose up -d
```

No arquivo local `airflow/.env`, configure também `OCI_CONFIG_HOST_DIR` e
`ORACLE_WALLET_HOST_DIR`. As credenciais do banco permanecem no `.env` da raiz,
lido diretamente pelo carregador dentro do volume do projeto; ele não deve ser
passado ao parser de variáveis do Docker Compose. Nenhum desses arquivos é
versionado.

A interface fica vinculada somente a `127.0.0.1:8080`.

## Implantação em uma VM OCI

Use uma VM com pelo menos 2 OCPUs, 8 GB de memória e espaço suficiente para os
arquivos temporários. O perfil Ampere A1 com 2 OCPUs e 12 GB é adequado para o
MVP quando houver capacidade disponível na região principal da tenancy.

Não abra a porta 8080 na internet. Conecte por SSH e crie um túnel local:

```bash
ssh -L 8080:127.0.0.1:8080 opc@IP_DA_VM
```

Então acesse `http://127.0.0.1:8080` no computador local. Use `ubuntu@IP_DA_VM`
se a imagem escolhida for Ubuntu.

## Próximas etapas

1. manter a DAG pausada durante a avaliação acadêmica;
2. validar as fontes da próxima competência antes de elevar conscientemente
   `HEALTH_DATA_AUTO_MAX_COMPETENCIA`;
3. implantar o mesmo Compose na VM OCI quando houver capacidade A1;
4. ativar a agenda somente após validar o primeiro ciclo da nova competência.

Credenciais, Wallet, chaves, `.env` e URLs PAR nunca devem ser versionadas.
