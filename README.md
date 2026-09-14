# Health Data — Challenge FIAP + Oracle

Plataforma de inteligência analítica para apoiar gestores da saúde pública
com informações acessíveis sobre internações, estabelecimentos e população.
O projeto utiliza dados públicos do SUS e do IBGE em uma arquitetura baseada
em serviços Oracle.

## Problema

Os dados necessários para orientar decisões de saúde já existem, mas ainda
exigem conhecimento técnico e consultas em sistemas fragmentados. Perguntas
como quais municípios concentram mais internações, quais hospitais apresentam
maior permanência média e quais atendimentos pressionam o orçamento podem
demorar dias para serem respondidas.

## Solução proposta

O Health Data organiza essas fontes em um modelo analítico no Oracle
Autonomous AI Database 26ai. A proposta completa combina:

- dashboards no Oracle APEX;
- perguntas em português convertidas em SQL pelo Oracle Select AI;
- alertas e indicadores para acompanhamento da pressão hospitalar;
- arquitetura preparada para análises estatísticas e modelos preditivos.

O recorte implementado utiliza dados do estado de São Paulo em 2024. A carga
operacional contém 2.855.539 internações distribuídas pelas 12 competências do
ano. Além das consultas históricas, o fluxo conversacional foi validado no APEX
com respostas em português sobre indicadores, municípios, estabelecimentos,
tipos de atendimento e uma projeção estatística explicável para a competência
seguinte.

## Demonstração pública

- [Aplicação Health Data](https://g2fcf3f6cff373b-healthdatadb.adb.sa-saopaulo-1.oraclecloudapps.com/ords/r/health_data/health-data/home)
- [Vídeo pitch](https://youtu.be/646NepJKuyI)

O acesso público existe para avaliação acadêmica. O App Builder, o SQL Workshop,
as credenciais do provedor de IA e os recursos administrativos não fazem parte
da superfície pública.

## Arquitetura

1. **Fontes:** SIH/SUS, API do CNES e população municipal do IBGE.
2. **Ingestão:** scripts Python baixam e normalizam os arquivos públicos.
3. **Camada Bronze:** fontes publicadas no OCI Object Storage em prefixos
   particionados. Tamanho e SHA-256 protegem contra sobrescritas divergentes.
4. **Camada Prata:** dimensões de municípios, estabelecimentos e tipos de
   atendimento, além da tabela fato de internações.
5. **Consumo:** dashboards e relatórios no Oracle APEX, com Assistente IA em
   linguagem natural integrado ao Oracle Select AI.

## Fontes e resultados da coleta

| Fonte | Saída local | Resultado registrado |
|---|---|---:|
| SIH/SUS — AIH Reduzida | `dados/sih_sp_2024_completo.parquet` | 2.855.539 internações, 12 meses |
| CNES — API de estabelecimentos | `dados/cnes_sp.parquet` | 152.567 estabelecimentos |
| IBGE — população municipal | `dados/ibge_populacao_sp_2024.csv` | 645 municípios |

Os arquivos em `dados/` são grandes ou regeneráveis e, por isso, não são
versionados. O DML permanece como uma amostra reprodutível para reconstrução
acadêmica: 645 municípios, 14 tipos de atendimento, 233 estabelecimentos e
5.925 internações. No ambiente operacional, o backfill incremental validado
carregou 2.855.539 internações, 638 estabelecimentos e 5.570 municípios na
dimensão geográfica nacional de apoio.

As descrições dos tipos de atendimento seguem a
[tabela de especialidades do leito do SIH/SUS](http://tabnet.datasus.gov.br/cgi/sih/sxdescr.htm).

## Estrutura do repositório

```text
.
├── baixar_sih_ftp_completo.py   # SIH/SUS completo pelo FTP oficial
├── baixar_cnes_api.py           # estabelecimentos pela API do CNES
├── baixar_ibge_populacao.py     # população municipal pelo XLS oficial do IBGE
├── gerar_dml.py                 # gera a carga SQL de exemplo
├── airflow/                     # Docker Compose e DAG de orquestração
├── src/health_data_pipeline/    # validações reutilizáveis do pipeline
├── tests/                       # testes automatizados do pipeline
├── apex/f100/                   # export dividido da aplicação APEX 100
├── sql/
│   ├── ddl_health_data.sql      # estruturas do banco
│   ├── dml_health_data.sql      # carga de exemplo
│   ├── etl_incremental.sql      # staging, auditoria e carga mensal transacional
│   ├── populacao_municipio_historica_20260911.sql # histórico anual do IBGE
│   ├── grants_apex_populacao_historica.sql # leitura da população pelo schema APEX
│   ├── apex_mvp_views.sql       # views analíticas consumidas pelo APEX
│   ├── previsao_internacoes.sql # série mensal, backtest e projeção explicável
│   ├── select_ai_previsao.sql   # inclui a projeção nos objetos do Select AI
│   └── apex_select_ai.sql       # função intermediária segura do Select AI
├── evidencias/sprint3/          # registros visuais da implementação de dados
└── evidencias/sprint4/          # evidências do MVP APEX
```

## Preparação do ambiente

Use Python 3.11, 3.12 ou 3.13 para manter compatibilidade com as dependências
utilizadas no projeto.

Crie um ambiente virtual com uma versão compatível e instale as dependências:

```bash
python -m venv .venv
```

No Windows PowerShell:

```powershell
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

No macOS ou Linux:

```bash
.venv/bin/python -m pip install -r requirements.txt
```

## Execução da coleta e geração do DML

Execute os scripts a partir da raiz, nesta ordem:

```bash
python baixar_sih_ftp_completo.py
python baixar_cnes_api.py
python baixar_ibge_populacao.py
python gerar_dml.py
```

O coletor SIH também aceita um recorte explícito, sem alterar o comportamento
padrão de `SP/2024` completo:

```bash
python baixar_sih_ftp_completo.py \
  --uf SP \
  --ano 2024 \
  --mes-inicio 10 \
  --mes-fim 12
```

Recortes mensais recebem nome próprio, como
`dados/sih_sp_2024_10_12.parquet`, para não sobrescrever o arquivo anual.

Os coletores cadastrais também aceitam parâmetros e preservam `SP/2024` como
padrão:

```bash
python baixar_cnes_api.py --uf MG
python baixar_ibge_populacao.py --uf MG --ano 2025 --url URL_OFICIAL_DO_XLS
```

Para edições do IBGE diferentes de 2024, a URL é obrigatória porque o endereço
e o nome do arquivo oficial podem mudar de um ano para outro.

Depois, no Oracle Database Actions ou SQL Developer:

1. revise e execute `sql/ddl_health_data.sql`;
2. execute uma vez `sql/etl_incremental.sql` para preparar staging e auditoria;
3. confirme a leitura da external table do IBGE;
4. execute `sql/dml_health_data.sql`;
5. valide as contagens e as chaves estrangeiras.

O pacote `pkg_health_data_etl` substitui somente a competência informada e
confirma a mesma contagem da staging antes do `COMMIT`. Qualquer falha executa
`ROLLBACK` e fica registrada em `etl_execucao`. O módulo
`src/health_data_pipeline/oracle_staging.py` prepara uma competência e as
quatro stagings; o comando `carregar_competencia_oracle.py` exige `--executar`
para escrever. O backfill de 2024 e o caminho idempotente da DAG incremental
foram validados no Autonomous Database.

O envio anual para a camada Bronze também começa em modo de planejamento. A
publicação real exige confirmação explícita e reutiliza um objeto somente quando
tamanho e SHA-256 são idênticos:

```bash
python publicar_bronze_ano.py \
  --bucket health-data-challenge \
  --data-extracao-cnes 2026-09-10

python publicar_bronze_ano.py \
  --bucket health-data-challenge \
  --data-extracao-cnes 2026-09-10 \
  --executar
```

O backfill anual também é somente leitura por padrão. Ele valida as 12
competências, os hashes no Bronze, o snapshot Oracle e as stagings antes de
exibir o token necessário para uma execução explícita:

```bash
python carregar_ano_oracle.py \
  --bucket health-data-challenge \
  --data-extracao-cnes 2026-09-10
```

Cada competência é publicada e reconciliada separadamente. Se uma competência
falhar, não prossiga com o dashboard até restaurar o snapshot usando
`sql/restore_sample_20260910.sql`.

Instalações que criaram o ETL antes da política de novas tentativas devem
executar uma vez `sql/etl_retry_fix_20260910.sql`. A carga desabilita Parallel
DML na própria sessão para que os `MERGE` das dimensões e a substituição mensal
da fato permaneçam na mesma transação.

Antes de uma carga, copie `.env.example` para um arquivo local ignorado pelo
Git e use uma wallet descompactada fora do repositório. O teste abaixo apenas
confirma a conexão e os objetos, sem alterar tabelas:

```bash
set -a
source .env
set +a
python testar_conexao_oracle.py
```

## Orquestração com Airflow

O diretório `airflow/` contém duas DAGs. A DAG histórica reproduz a amostra e
permanece sem agenda. A DAG `health_data_incremental` coleta uma competência,
valida e publica as fontes Bronze, carrega as stagings, executa o pacote Oracle
e reconcilia o resultado. O primeiro disparo manual reutilizou com segurança a
carga de `12/2024` e reconciliou 225.756 internações sem duplicação. A agenda
mensal está configurada para o dia 15 às 06:00 no fuso de São Paulo, mas a DAG
permanece pausada e protegida pela trava `HEALTH_DATA_AUTO_MAX_COMPETENCIA=202412`
durante o fechamento acadêmico. Consulte `airflow/README.md`.

## Restauração do MVP APEX

O diretório `apex/f100/` contém o export SQL dividido da aplicação 100, com IDs
originais preservados para facilitar comparações no Git. Para reconstruir o
MVP em outro ambiente:

1. execute `sql/ddl_health_data.sql` e `sql/dml_health_data.sql`;
2. execute `sql/apex_mvp_views.sql` no schema associado ao workspace APEX;
3. configure fora do repositório a credencial e o profile do provedor de IA;
4. execute `sql/apex_select_ai.sql` como proprietário da função e confira o
   `GRANT EXECUTE` ao schema APEX;
5. importe `apex/f100/install.sql` pelo APEX ou execute o conjunto de arquivos
   no ambiente de destino.

Para habilitar a projeção estatística sem alterar a interface, execute também
`sql/previsao_internacoes.sql` no schema do workspace depois das views do MVP.
O script cria a série mensal observada, o backtest e a projeção para a próxima
competência por média móvel ponderada de três meses. A faixa informada usa o
erro absoluto médio retrospectivo e é identificada explicitamente como
indicativa, não como intervalo de confiança.

Depois da criação das views, `sql/select_ai_previsao.sql` adiciona ao profile
existente somente as visões mensais e preditivas, além das instruções semânticas
que impedem dupla contagem entre total e tipos de atendimento. A credencial e o
profile base precisam ser configurados separadamente pelo administrador.

A chave do provedor, a credencial protegida no banco e demais segredos não são
exportados nem versionados. O código APEX chama somente a função intermediária
`ADMIN.HEALTH_DATA_SELECT_AI`.

## Configuração segura da external table

O DDL versionado usa o placeholder `<PAR_URL_AQUI>`. Para executar a criação
da external table, faça uma cópia local do DDL, substitua o placeholder pela
URL da Pre-Authenticated Request do OCI e não versione essa cópia. Uma PAR é
uma credencial de acesso e não deve aparecer em código, documentação ou
capturas públicas.

## Proveniência e governança dos dados

Os registros de internação utilizados na carga de exemplo derivam dos arquivos
dissemináveis da AIH Reduzida do Sistema de Informações Hospitalares do SUS
(SIH/SUS), disponibilizados publicamente pelo DATASUS. O Ministério da Saúde
mantém o [acesso público ao SIH/SUS](https://datasus.saude.gov.br/acesso-a-informacao/producao-hospitalar-sih-sus/)
e documenta a [origem e o processamento das informações hospitalares](https://tabnet.datasus.gov.br/cgi/sih/rxdescr.htm).

O conjunto versionado destina-se exclusivamente a fins acadêmicos e analíticos
e não contém nome, CPF, CNS ou outros identificadores pessoais diretos. Por
minimização de dados, o campo de origem `N_AIH`, que não participa das análises
nem dos relacionamentos do modelo, não é publicado. A tabela fato utiliza uma
chave substituta gerada pelo Oracle.

Este repositório não atribui aos dados uma licença diferente da estabelecida
pelas fontes oficiais. A disponibilidade pública e a proveniência não dispensam
a observância dos termos e das condições aplicáveis nas fontes do Ministério da
Saúde, DATASUS e IBGE.

## Observações sobre as fontes

- O coletor do SIH usa diretamente o FTP oficial do DATASUS porque o mirror
  comunitário consultado não continha os 12 arquivos mensais de 2024.
- Na API do CNES, o filtro funcional para São Paulo é `codigo_uf=35`; a sigla
  `uf=SP` é aceita, mas ignorada.
- A população municipal é obtida diretamente da publicação oficial
  "Estimativas da População 2024" do IBGE. O script lê a aba de municípios,
  filtra o estado de São Paulo e gera o CSV usado pela external table.

## Equipe

- Lucas Leal das Chagas — RM571567
- Matheus Carvalho de Souza — RM568785
- Vinicius de Assis Araujo — RM570900

Turma 1TSCPW — Challenge FIAP + Oracle, 2026.
