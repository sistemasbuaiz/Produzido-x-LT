# ZPPR014 – Comparativo Produzido Real x LT Planejado

## Visão Geral

Relatório SAP do módulo **PP (Planejamento de Produção)** que apresenta o comparativo entre a produção real e o Lead Time planejado para todos os **produtos acabados (FERT)** e **semi-acabados (HALB)** dos centros **BAMO**, **CDTR** e **CFMA**.

## Funcionalidades

| Funcionalidade | Detalhe |
|---|---|
| Centros suportados | BAMO, CDTR, CFMA |
| Tipos de material | FERT (Produto Acabado), HALB (Semi-Acabado) |
| Filtro por status | Criada, Liberada, Conf. Parcial, TECO, Fechada |
| Filtro por período | Data início e fim planejadas da ordem |
| Filtro por ordem | Número e tipo de ordem |
| Exibição | ALV Grid com toolbar completa (exportar, filtrar, ordenar) |

## Colunas do Relatório

### Identificação
- **Centro** – Centro de produção (AFKO-WERKS)
- **Material** – Número do material (AFKO-MATNR)
- **Descrição** – Texto do material (MAKT-MAKTX)
- **Tipo Mat.** – FERT ou HALB (MARA-MTART)
- **Nº Ordem** – Número da ordem de produção (AFKO-AUFNR)
- **Tipo Ordem** – Tipo de ordem PP (AUFK-AUART)

### Datas Planejadas x Reais
- **Dt. Início Plan.** – Data início programada (AFKO-GSTRS)
- **Dt. Fim Plan.** – Data fim programada (AFKO-GLTRP)
- **Dt. Início Real** – Data início confirmada (AFKO-FTRMS)
- **Dt. Fim Real** – Data fim confirmada (AFKO-GETRS)

### Comparativo de Quantidades
- **Qtd. Planejada** – Quantidade total da ordem (AFKO-GAMNG)
- **Qtd. Produzida** – Quantidade com entrada de mercadoria (AFKO-WEMNG)
- **UM** – Unidade de medida (AFKO-GMEIN)
- **Variação Qtd.** – `WEMNG − GAMNG`
- **% Variação** – `(Var. Qtd. / Qtd. Plan.) × 100`

### Comparativo de Lead Time
- **LT Planejado (d)** – LT em dias úteis do mestre de materiais (MARC-DZEIT)
- **LT Real (d)** – Dias corridos entre `FTRMS` e `GETRS`
- **Variação LT (d)** – `LT Real − LT Planejado`

### Indicador de Desempenho
| Cor | Condição |
|---|---|
| **G** – Verde | Desvio de qtd ≤ 10% **e** variação de LT ≤ 0 dias |
| **Y** – Amarelo | Desvio de qtd entre 10% e 20% **ou** variação de LT 1–2 dias |
| **R** – Vermelho | Desvio de qtd > 20% **ou** variação de LT > 2 dias |

## Tabelas SAP Utilizadas

| Tabela | Descrição |
|---|---|
| `AUFK` | Dados mestre da ordem de produção |
| `AFKO` | Cabeçalho da ordem PP (datas, quantidades) |
| `AFPO` | Itens da ordem PP |
| `MARC` | Dados de planejamento por centro (LT planejado: DZEIT) |
| `MARA` | Dados gerais do material (tipo: MTART) |
| `MAKT` | Textos do material |
| `JEST` | Status do sistema por objeto |
| `T001W` | Centros |

## Implantação no SAP

1. Acessar transação **SE38** (Editor ABAP)
2. Criar programa com nome **ZPPR014**
3. Copiar o conteúdo de `ZPPR014.abap`
4. Ativar o programa (`Ctrl+F3`)
5. Criar textos de tela de seleção via **Ir para → Textos** com os valores de `ZPPR014_TEXTOS.txt`
6. Criar transação via **SE93**:
   - Transação: `ZPPR014`
   - Tipo: `1 – Transação ABAP`
   - Programa: `ZPPR014`
   - Marcar: *Ignorar tela de seleção*: Não

## Estrutura de Arquivos

```
Produzido-x-LT/
├── ZPPR014.abap          # Código-fonte principal do relatório
├── ZPPR014_TEXTOS.txt    # Textos de tela de seleção e referência de campos
└── README.md             # Esta documentação
```
