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

O recorte implementado nesta etapa utiliza dados do estado de São Paulo em
2024. O banco relacional, a carga de exemplo e as evidências já produzidas na
Sprint 3 estão disponíveis neste repositório. A Sprint 3 permanece em
desenvolvimento; na disciplina Data Architecture, Analytics & NoSQL Solutions,
1 das 3 consultas `SELECT AI SHOWSQL` previstas foi concluída.

## Arquitetura

1. **Fontes:** SIH/SUS, API do CNES e população municipal do IBGE.
2. **Ingestão:** scripts Python baixam e normalizam os arquivos públicos.
3. **Camada Bronze:** CSV do IBGE armazenado no OCI Object Storage e lido por
   uma external table.
4. **Camada Prata:** dimensões de municípios, estabelecimentos e tipos de
   atendimento, além da tabela fato de internações.
5. **Consumo:** Oracle Select AI e, na evolução do MVP, dashboards no APEX.

## Fontes e resultados da coleta

| Fonte | Saída local | Resultado registrado |
|---|---|---:|
| SIH/SUS — AIH Reduzida | `dados/sih_sp_2024_completo.parquet` | 2.855.539 internações, 12 meses |
| CNES — API de estabelecimentos | `dados/cnes_sp.parquet` | 152.567 estabelecimentos |
| IBGE — população municipal | `dados/ibge_populacao_sp_2024.csv` | 645 municípios |

Os arquivos em `dados/` são grandes ou regeneráveis e, por isso, não são
versionados. O DML entregue contém uma amostra reprodutível: 645 municípios,
14 tipos de atendimento, 233 estabelecimentos e 5.925 internações.

## Estrutura do repositório

```text
.
├── baixar_sih_ftp_completo.py   # SIH/SUS completo pelo FTP oficial
├── baixar_cnes_api.py           # estabelecimentos pela API do CNES
├── baixar_ibge_populacao.py     # população municipal pelo PySUS
├── gerar_dml.py                 # gera a carga SQL de exemplo
├── sql/
│   ├── ddl_health_data.sql      # estruturas do banco
│   └── dml_health_data.sql      # carga de exemplo
└── evidencias/sprint3/          # registros visuais da implementação
```

## Preparação do ambiente

Use Python 3.11, 3.12 ou 3.13. O PySUS utilizado pelo projeto ainda não
oferece suporte ao Python 3.14.

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

Depois, no Oracle Database Actions ou SQL Developer:

1. revise e execute `sql/ddl_health_data.sql`;
2. confirme a leitura da external table do IBGE;
3. execute `sql/dml_health_data.sql`;
4. valide as contagens e as chaves estrangeiras.

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
- O retorno do IBGE via PySUS reúne projeções estaduais e população municipal;
  o script seleciona os registros municipais pelo campo `MUNIC_RES`.

## Equipe

- Lucas Leal das Chagas — RM571567
- Matheus Carvalho de Souza — RM568785
- Vinicius de Assis Araujo — RM570900

Turma 1TSCPW — Challenge FIAP + Oracle, 2026.
