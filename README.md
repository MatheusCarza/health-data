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

O recorte implementado utiliza dados do estado de São Paulo em 2024. O banco
relacional, a carga de exemplo, as evidências da Sprint 3 e o MVP APEX estão
disponíveis neste repositório. Além das três consultas `SELECT AI SHOWSQL`, o
fluxo conversacional foi validado no APEX com respostas em português para
resumo geral, município, estabelecimento e tipo de atendimento.

## Arquitetura

1. **Fontes:** SIH/SUS, API do CNES e população municipal do IBGE.
2. **Ingestão:** scripts Python baixam e normalizam os arquivos públicos.
3. **Camada Bronze:** CSV do IBGE armazenado no OCI Object Storage e lido por
   uma external table.
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
versionados. O DML entregue contém uma amostra reprodutível: 645 municípios,
14 tipos de atendimento, 233 estabelecimentos e 5.925 internações.

As descrições dos tipos de atendimento seguem a
[tabela de especialidades do leito do SIH/SUS](http://tabnet.datasus.gov.br/cgi/sih/sxdescr.htm).

## Estrutura do repositório

```text
.
├── baixar_sih_ftp_completo.py   # SIH/SUS completo pelo FTP oficial
├── baixar_cnes_api.py           # estabelecimentos pela API do CNES
├── baixar_ibge_populacao.py     # população municipal pelo XLS oficial do IBGE
├── gerar_dml.py                 # gera a carga SQL de exemplo
├── apex/f100/                   # export dividido da aplicação APEX 100
├── sql/
│   ├── ddl_health_data.sql      # estruturas do banco
│   ├── dml_health_data.sql      # carga de exemplo
│   ├── apex_mvp_views.sql       # views analíticas consumidas pelo APEX
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

Depois, no Oracle Database Actions ou SQL Developer:

1. revise e execute `sql/ddl_health_data.sql`;
2. confirme a leitura da external table do IBGE;
3. execute `sql/dml_health_data.sql`;
4. valide as contagens e as chaves estrangeiras.

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
