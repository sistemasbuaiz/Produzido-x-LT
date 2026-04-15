*&---------------------------------------------------------------------*
*& Report  : ZPPR014
*& Módulo  : PP - Planejamento de Produção
*&---------------------------------------------------------------------*
*& Descrição: Comparativo Produzido Real x LT Planejado
*&            Exibe para todos os produtos acabados (FERT) e
*&            semi-acabados (HALB) dos centros BAMO, CDTR e CFMA:
*&              - Quantidade planejada vs. quantidade produzida real
*&              - Lead Time planejado (MARC-DZEIT) vs. LT real
*&              - Variações absolutas e percentuais
*&---------------------------------------------------------------------*
*& Tabelas SAP utilizadas:
*&   AUFK  - Dados mestre de ordens de produção
*&   AFKO  - Cabeçalho de ordens PP
*&   AFPO  - Itens de ordens PP
*&   MARC  - Dados de planejamento do material por centro
*&   MARA  - Dados gerais do material
*&   MAKT  - Textos do material
*&   T001W - Centros
*&---------------------------------------------------------------------*
REPORT zppr014
  LINE-SIZE  255
  LINE-COUNT 65
  NO STANDARD PAGE HEADING
  MESSAGE-ID zmm.

*----------------------------------------------------------------------*
* DECLARAÇÃO DE TABELAS DO DICIONÁRIO
*----------------------------------------------------------------------*
TABLES: marc,
        mara,
        aufk,
        afko.

*----------------------------------------------------------------------*
* TIPOS DE DADOS
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_selrange_werks,
    sign   TYPE c LENGTH 1,
    option TYPE c LENGTH 2,
    low    TYPE werks_d,
    high   TYPE werks_d,
  END OF ty_selrange_werks,

  BEGIN OF ty_ordem,
    aufnr TYPE aufnr,       " Número da ordem
    auart TYPE auart,       " Tipo de ordem
    werks TYPE werks_d,     " Centro
    matnr TYPE matnr,       " Material
    gamng TYPE gamng,       " Qtd planejada total
    wemng TYPE wemng,       " Qtd entrada mercadoria (produzida)
    gmein TYPE meins,       " Unidade de medida (data element MEINS)
    gstrs TYPE gstrs,       " Data início planejada
    gltrp TYPE gltrp,       " Data fim planejada
    ftrms TYPE ftrms,       " Data início confirmada
    getrs TYPE afko-getri,  " Data fim real (AFKO-GETRI: Ist-Endtermin)
  END OF ty_ordem,

  BEGIN OF ty_marc,
    matnr TYPE matnr,
    werks TYPE werks_d,
    mtart TYPE mtart,
    dzeit TYPE dzeit,       " LT planejado em dias úteis
  END OF ty_marc,

  BEGIN OF ty_makt,
    matnr TYPE matnr,
    maktx TYPE maktx,
  END OF ty_makt,

  BEGIN OF ty_dados,
    werks    TYPE werks_d,
    matnr    TYPE matnr,
    maktx    TYPE maktx,
    mtart    TYPE mtart,
    aufnr    TYPE aufnr,
    auart    TYPE auart,
    gstrs    TYPE gstrs,
    gltrp    TYPE gltrp,
    ftrms    TYPE ftrms,
    getrs    TYPE afko-getri,  " Data fim real (AFKO-GETRI: Ist-Endtermin)
    gamng    TYPE gamng,
    wemng    TYPE wemng,
    gmein    TYPE meins,
    dzeit    TYPE dzeit,
    lt_real  TYPE i,
    lt_var   TYPE i,
    qty_var  TYPE p LENGTH 8 DECIMALS 3,
    pct_var  TYPE p LENGTH 8 DECIMALS 2,
    semaforo TYPE c LENGTH 1,  " R=Vermelho, Y=Amarelo, G=Verde
  END OF ty_dados.

*----------------------------------------------------------------------*
* TABELAS INTERNAS E WORK AREAS
*----------------------------------------------------------------------*
DATA:
  gt_ordens TYPE STANDARD TABLE OF ty_ordem,
  gs_ordem  TYPE ty_ordem,
  gt_marc   TYPE STANDARD TABLE OF ty_marc,
  gs_marc   TYPE ty_marc,
  gt_makt   TYPE STANDARD TABLE OF ty_makt,
  gs_makt   TYPE ty_makt,
  gt_dados  TYPE STANDARD TABLE OF ty_dados,
  gs_dados  TYPE ty_dados.

*----------------------------------------------------------------------*
* VARIÁVEIS AUXILIARES
*----------------------------------------------------------------------*
DATA:
  gv_lt_real   TYPE i,
  gv_days_plan TYPE i,
  gv_days_real TYPE i.

*----------------------------------------------------------------------*
* CONSTANTES
*----------------------------------------------------------------------*
CONSTANTS:
  gc_fert   TYPE mtart    VALUE 'FERT',
  gc_halb   TYPE mtart    VALUE 'HALB',
  gc_bamo   TYPE werks_d  VALUE 'BAMO',
  gc_cdtr   TYPE werks_d  VALUE 'CDTR',
  gc_cfma   TYPE werks_d  VALUE 'CFMA',
  gc_verde  TYPE c        VALUE 'G',
  gc_amar   TYPE c        VALUE 'Y',
  gc_verm   TYPE c        VALUE 'R',
  gc_x      TYPE c        VALUE 'X'.

*----------------------------------------------------------------------*
* TELA DE SELEÇÃO
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS:
    so_werks FOR marc-werks        " Centro(s)
             DEFAULT gc_bamo TO gc_cfma,
    so_matnr FOR marc-matnr,       " Material
    so_mtart FOR mara-mtart        " Tipo de material
             DEFAULT gc_fert TO gc_halb,
    so_auart FOR aufk-auart,       " Tipo de ordem
    so_aufnr FOR aufk-aufnr.       " Nº ordem
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS:
    so_gstrs FOR afko-gstrs OBLIGATORY,   " Data início planejada
    so_gltrp FOR afko-gltrp.              " Data fim planejada
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  PARAMETERS:
    p_aber  AS CHECKBOX DEFAULT gc_x,  " Abertas (REL)
    p_liber AS CHECKBOX DEFAULT gc_x,  " Liberadas (LIB)
    p_conf  AS CHECKBOX DEFAULT gc_x,  " Confirmadas (CNF)
    p_encr  AS CHECKBOX DEFAULT gc_x,  " Encerradas (TECO)
    p_fech  AS CHECKBOX.               " Fechadas (CLSD)
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* EVENTOS DE TELA DE SELEÇÃO
*----------------------------------------------------------------------*
INITIALIZATION.
  PERFORM f_init_selscreen.

AT SELECTION-SCREEN.
  PERFORM f_validate_selscreen.

*----------------------------------------------------------------------*
* PROCESSAMENTO PRINCIPAL
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM f_selecionar_ordens.
  PERFORM f_selecionar_materiais.
  PERFORM f_montar_saida.
  PERFORM f_exibir_alv.

*&---------------------------------------------------------------------*
*& ROTINAS (FORMS)
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form F_INIT_SELSCREEN
*& Inicializa valores default da tela de seleção
*&---------------------------------------------------------------------*
FORM f_init_selscreen.

  " Define o intervalo de datas default: mês corrente
  so_gstrs-sign   = 'I'.
  so_gstrs-option = 'BT'.
  so_gstrs-low    = |{ sy-datum(4) }{ sy-datum+4(2) }01|.
  so_gstrs-high   = sy-datum.
  APPEND so_gstrs.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_VALIDATE_SELSCREEN
*& Valida entradas da tela de seleção
*&---------------------------------------------------------------------*
FORM f_validate_selscreen.

  " Ao menos um status deve ser selecionado
  IF p_aber = space AND p_liber = space AND p_conf = space
     AND p_encr = space AND p_fech = space.
    MESSAGE 'Selecione ao menos um status de ordem.' TYPE 'E'.
  ENDIF.

  " Centro deve estar entre os centros permitidos
  DATA(lv_werks_ok) = abap_false.
  LOOP AT so_werks ASSIGNING FIELD-SYMBOL(<fs_w>).
    IF <fs_w>-low = gc_bamo OR <fs_w>-low = gc_cdtr OR <fs_w>-low = gc_cfma
       OR <fs_w>-high = gc_bamo OR <fs_w>-high = gc_cdtr OR <fs_w>-high = gc_cfma.
      lv_werks_ok = abap_true.
    ENDIF.
  ENDLOOP.
  IF lv_werks_ok = abap_false AND lines( so_werks ) > 0.
    MESSAGE 'Atenção: selecione centros válidos: BAMO, CDTR ou CFMA.' TYPE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_SELECIONAR_ORDENS
*& Busca ordens de produção conforme critérios de seleção
*&---------------------------------------------------------------------*
FORM f_selecionar_ordens.

  " Monta condição de status de sistema via JEST/TJ02T
  " A filtragem por status é feita após a leitura inicial via AFKO/AUFK

  " MATNR e WEMNG ficam em AFPO; WERKS fica em AUFK; datas e GAMNG em AFKO
  SELECT
    afko~aufnr,
    aufk~auart,
    aufk~werks,         " Centro (AUFK-WERKS)
    afpo~matnr,         " Material (AFPO-MATNR)
    afko~gamng,         " Qtd planejada total (AFKO-GAMNG)
    afpo~wemng,         " Qtd entrada merc. produzida (AFPO-WEMNG)
    afko~gmein,         " Unidade de medida (AFKO-GMEIN)
    afko~gstrs,
    afko~gltrp,
    afko~ftrms,
    afko~getri  " Data fim real (Ist-Endtermin)
  INTO TABLE @gt_ordens
  FROM afko
  INNER JOIN aufk ON aufk~aufnr  = afko~aufnr
  INNER JOIN afpo ON afpo~aufnr  = afko~aufnr
  INNER JOIN marc ON  marc~matnr = afpo~matnr
                  AND marc~werks = aufk~werks
  INNER JOIN mara ON  mara~matnr = afpo~matnr
  WHERE aufk~werks   IN @so_werks
    AND afpo~matnr   IN @so_matnr
    AND afko~gstrs   IN @so_gstrs
    AND afko~gltrp   IN @so_gltrp
    AND aufk~aufnr   IN @so_aufnr
    AND aufk~auart   IN @so_auart
    AND mara~mtart   IN @so_mtart
    AND mara~mtart   IN ('FERT', 'HALB').   " Somente FERT e HALB

  IF sy-subrc <> 0.
    MESSAGE 'Nenhuma ordem encontrada com os critérios informados.' TYPE 'S'
            DISPLAY LIKE 'W'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Filtra por status de sistema usando OBJNR de AUFK
  PERFORM f_filtrar_por_status.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_FILTRAR_POR_STATUS
*& Filtra ordens conforme status de sistema selecionados (JEST)
*&---------------------------------------------------------------------*
FORM f_filtrar_por_status.

  DATA:
    lt_objnr  TYPE STANDARD TABLE OF j_objnr,
    lt_jest   TYPE STANDARD TABLE OF jest,
    ls_jest   TYPE jest,
    lt_keep   TYPE STANDARD TABLE OF aufnr.

  " Coleta todos OBJNR das ordens selecionadas
  SELECT aufnr~aufnr, aufk~objnr
  INTO TABLE @DATA(lt_aufk_objnr)
  FROM aufk
  FOR ALL ENTRIES IN @gt_ordens
  WHERE aufk~aufnr = @gt_ordens-aufnr.

  " Lê status ativos da tabela JEST
  IF lt_aufk_objnr IS NOT INITIAL.
    SELECT *
    INTO TABLE @lt_jest
    FROM jest
    FOR ALL ENTRIES IN @lt_aufk_objnr
    WHERE objnr = @lt_aufk_objnr-objnr
      AND inact = space.
  ENDIF.

  " Verifica quais ordens atendem aos status selecionados
  LOOP AT gt_ordens ASSIGNING FIELD-SYMBOL(<fs_ord>).

    READ TABLE lt_aufk_objnr ASSIGNING FIELD-SYMBOL(<fs_ao>)
      WITH KEY aufnr = <fs_ord>-aufnr.
    IF sy-subrc <> 0.
      DELETE gt_ordens.
      CONTINUE.
    ENDIF.

    DATA(lv_manter) = abap_false.

    " REL - Criada/Liberada (I0001)
    IF p_aber = gc_x.
      READ TABLE lt_jest WITH KEY objnr = <fs_ao>-objnr
                                  stat  = 'I0001' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0. lv_manter = abap_true. ENDIF.
    ENDIF.
    " LIB - Liberada (I0002)
    IF p_liber = gc_x AND lv_manter = abap_false.
      READ TABLE lt_jest WITH KEY objnr = <fs_ao>-objnr
                                  stat  = 'I0002' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0. lv_manter = abap_true. ENDIF.
    ENDIF.
    " CNF - Confirmada parcialmente (I0010)
    IF p_conf = gc_x AND lv_manter = abap_false.
      READ TABLE lt_jest WITH KEY objnr = <fs_ao>-objnr
                                  stat  = 'I0010' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0. lv_manter = abap_true. ENDIF.
    ENDIF.
    " TECO - Encerrada tecnicamente (I0045)
    IF p_encr = gc_x AND lv_manter = abap_false.
      READ TABLE lt_jest WITH KEY objnr = <fs_ao>-objnr
                                  stat  = 'I0045' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0. lv_manter = abap_true. ENDIF.
    ENDIF.
    " CLSD - Fechada (I0046)
    IF p_fech = gc_x AND lv_manter = abap_false.
      READ TABLE lt_jest WITH KEY objnr = <fs_ao>-objnr
                                  stat  = 'I0046' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0. lv_manter = abap_true. ENDIF.
    ENDIF.

    IF lv_manter = abap_false.
      DELETE gt_ordens.
    ENDIF.

  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_SELECIONAR_MATERIAIS
*& Busca dados do material (MARC + MAKT) para ordens filtradas
*&---------------------------------------------------------------------*
FORM f_selecionar_materiais.

  IF gt_ordens IS INITIAL.
    RETURN.
  ENDIF.

  " Dados de planejamento do centro (LT planejado)
  SELECT marc~matnr,
         marc~werks,
         mara~mtart,
         marc~dzeit
  INTO TABLE @gt_marc
  FROM marc
  INNER JOIN mara ON mara~matnr = marc~matnr
  FOR ALL ENTRIES IN @gt_ordens
  WHERE marc~matnr = @gt_ordens-matnr
    AND marc~werks = @gt_ordens-werks.

  " Descrição dos materiais (idioma logon)
  SELECT matnr, maktx
  INTO TABLE @gt_makt
  FROM makt
  FOR ALL ENTRIES IN @gt_ordens
  WHERE matnr = @gt_ordens-matnr
    AND spras = @sy-langu.

  SORT gt_marc BY matnr werks.
  SORT gt_makt BY matnr.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_MONTAR_SAIDA
*& Consolida dados e calcula variações para exibição
*&---------------------------------------------------------------------*
FORM f_montar_saida.

  LOOP AT gt_ordens INTO gs_ordem.

    CLEAR gs_dados.

    " Dados básicos da ordem
    gs_dados-aufnr = gs_ordem-aufnr.
    gs_dados-auart = gs_ordem-auart.
    gs_dados-werks = gs_ordem-werks.
    gs_dados-matnr = gs_ordem-matnr.
    gs_dados-gamng = gs_ordem-gamng.
    gs_dados-wemng = gs_ordem-wemng.
    gs_dados-gmein = gs_ordem-gmein.
    gs_dados-gstrs = gs_ordem-gstrs.
    gs_dados-gltrp = gs_ordem-gltrp.
    gs_dados-ftrms = gs_ordem-ftrms.
    gs_dados-getrs = gs_ordem-getrs.

    " Descrição do material
    READ TABLE gt_makt INTO gs_makt
      WITH KEY matnr = gs_ordem-matnr BINARY SEARCH.
    IF sy-subrc = 0.
      gs_dados-maktx = gs_makt-maktx.
    ENDIF.

    " Dados do centro: tipo de material e LT planejado
    READ TABLE gt_marc INTO gs_marc
      WITH KEY matnr = gs_ordem-matnr
               werks = gs_ordem-werks BINARY SEARCH.
    IF sy-subrc = 0.
      gs_dados-mtart = gs_marc-mtart.
      gs_dados-dzeit = gs_marc-dzeit.
    ENDIF.

    " Calcula LT real (dias corridos entre datas reais)
    PERFORM f_calcular_lt_real
      USING    gs_ordem-ftrms
               gs_ordem-getrs
      CHANGING gv_lt_real.
    gs_dados-lt_real = gv_lt_real.

    " Variação de LT: Real - Planejado
    IF gs_dados-dzeit > 0 AND gs_dados-lt_real > 0.
      gs_dados-lt_var = gs_dados-lt_real - gs_dados-dzeit.
    ENDIF.

    " Variação de quantidade: Real - Planejado
    IF gs_ordem-gamng > 0.
      gs_dados-qty_var = gs_ordem-wemng - gs_ordem-gamng.
      gs_dados-pct_var = ( gs_dados-qty_var / gs_ordem-gamng ) * 100.
    ENDIF.

    " Semáforo de desvio (tolerância: ±10%)
    PERFORM f_semaforo
      USING    gs_dados-pct_var
               gs_dados-lt_var
      CHANGING gs_dados-semaforo.

    APPEND gs_dados TO gt_dados.

  ENDLOOP.

  SORT gt_dados BY werks matnr aufnr.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_CALCULAR_LT_REAL
*& Calcula dias corridos entre data início real e data fim real
*&---------------------------------------------------------------------*
FORM f_calcular_lt_real
  USING    pv_inicio TYPE d
           pv_fim    TYPE d
  CHANGING pv_dias   TYPE i.

  pv_dias = 0.
  IF pv_inicio IS NOT INITIAL AND pv_fim IS NOT INITIAL
     AND pv_fim >= pv_inicio.
    pv_dias = pv_fim - pv_inicio.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_SEMAFORO
*& Define indicador de desempenho (verde/amarelo/vermelho)
*& Verde  : desvio qty <=10% e LT dentro do planejado
*& Amarelo: desvio qty entre 10% e 20%, ou LT até +2 dias
*& Vermelho: desvio qty >20% ou LT > +2 dias
*&---------------------------------------------------------------------*
FORM f_semaforo
  USING    pv_pct_var TYPE p
           pv_lt_var  TYPE i
  CHANGING pv_sema    TYPE c.

  DATA(lv_pct_abs) = abs( pv_pct_var ).

  IF lv_pct_abs > 20 OR pv_lt_var > 2.
    pv_sema = gc_verm.
  ELSEIF lv_pct_abs > 10 OR pv_lt_var > 0.
    pv_sema = gc_amar.
  ELSE.
    pv_sema = gc_verde.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_EXIBIR_ALV
*& Monta e exibe relatório ALV com os dados consolidados
*&---------------------------------------------------------------------*
FORM f_exibir_alv.

  DATA:
    lo_alv      TYPE REF TO cl_salv_table,
    lo_columns  TYPE REF TO cl_salv_columns_table,
    lo_column   TYPE REF TO cl_salv_column_table,
    lo_sorts    TYPE REF TO cl_salv_sorts,
    lo_display  TYPE REF TO cl_salv_display_settings,
    lo_funcs    TYPE REF TO cl_salv_functions_list,
    lo_events   TYPE REF TO cl_salv_events_table,
    lx_msg      TYPE REF TO cx_salv_msg,
    lx_exist    TYPE REF TO cx_salv_existing_object,
    lx_col      TYPE REF TO cx_salv_not_found.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = gt_dados ).

    CATCH cx_salv_msg INTO lx_msg.
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
      RETURN.
  ENDTRY.

  " ---- Funções padrão (botões toolbar) ----------------------------
  lo_funcs = lo_alv->get_functions( ).
  lo_funcs->set_all( abap_true ).

  " ---- Configurações de exibição ----------------------------------
  lo_display = lo_alv->get_display_settings( ).
  lo_display->set_list_header( 'Comparativo: Produzido Real x LT Planejado' ).
  lo_display->set_striped_pattern( abap_true ).
  lo_display->set_fit_column_to_table_size( abap_true ).

  " ---- Ordenação padrão ------------------------------------------
  lo_sorts = lo_alv->get_sorts( ).
  TRY.
      lo_sorts->add_sort( columnname = 'WERKS' ).
      lo_sorts->add_sort( columnname = 'MATNR' ).
    CATCH cx_salv_not_found cx_salv_existing_object cx_salv_data_error.
  ENDTRY.

  " ---- Configuração de colunas ------------------------------------
  lo_columns = lo_alv->get_columns( ).
  lo_columns->set_optimize( abap_true ).

  PERFORM f_configurar_colunas USING lo_columns.

  " ---- Exibe o ALV ------------------------------------------------
  lo_alv->display( ).

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_CONFIGURAR_COLUNAS
*& Define rótulos, visibilidade e propriedades das colunas ALV
*&---------------------------------------------------------------------*
FORM f_configurar_colunas
  USING po_columns TYPE REF TO cl_salv_columns_table.

  DATA lo_col TYPE REF TO cl_salv_column_table.

  DEFINE set_col.
    TRY.
        lo_col ?= po_columns->get_column( &1 ).
        lo_col->set_short_text( &2 ).
        lo_col->set_medium_text( &3 ).
        lo_col->set_long_text( &4 ).
      CATCH cx_salv_not_found.
    ENDTRY.
  END-OF-DEFINITION.

  " -- Campos identificadores
  set_col 'WERKS'   'Centro'   'Centro'         'Centro'.
  set_col 'MATNR'   'Material' 'Nº Material'    'Número do Material'.
  set_col 'MAKTX'   'Descrição' 'Descrição Mat.' 'Descrição do Material'.
  set_col 'MTART'   'Tp.Mat'   'Tipo Material'  'Tipo de Material'.
  set_col 'AUFNR'   'Ordem'    'Nº Ordem'       'Número da Ordem de Produção'.
  set_col 'AUART'   'Tp.Ord'   'Tipo Ordem'     'Tipo de Ordem'.

  " -- Datas planejadas
  set_col 'GSTRS'   'Dt.Ini.Pl' 'Dt.Ini.Plan.'  'Data Início Planejada'.
  set_col 'GLTRP'   'Dt.Fim.Pl' 'Dt.Fim.Plan.'  'Data Fim Planejada'.

  " -- Datas reais
  set_col 'FTRMS'   'Dt.Ini.Re' 'Dt.Ini.Real'   'Data Início Real (Confirmada)'.
  set_col 'GETRS'   'Dt.Fim.Re' 'Dt.Fim.Real'   'Data Fim Real (Confirmada)'.

  " -- Quantidades
  set_col 'GAMNG'   'Qtd.Plan.' 'Qtd.Planejada' 'Quantidade Total Planejada'.
  set_col 'WEMNG'   'Qtd.Real'  'Qtd.Produzida' 'Quantidade Produzida (Entrada Merc.)'.
  set_col 'GMEIN'   'UM'        'Unid.Medida'   'Unidade de Medida'.
  set_col 'QTY_VAR' 'Var.Qtd'   'Variação Qtd.' 'Variação de Quantidade (Real - Plan.)'.
  set_col 'PCT_VAR' '% Var.'    '% Variação'    'Percentual de Variação de Quantidade'.

  " -- Lead Times
  set_col 'DZEIT'   'LT Plan.(d)' 'LT Planejado' 'Lead Time Planejado (dias úteis, MARC-DZEIT)'.
  set_col 'LT_REAL' 'LT Real (d)' 'LT Real'      'Lead Time Real (dias corridos entre datas)'.
  set_col 'LT_VAR'  'Var.LT(d)'   'Variação LT'  'Variação de Lead Time (Real - Planejado)'.

  " -- Indicador
  set_col 'SEMAFORO' 'Status' 'Indicador' 'Indicador de Desempenho (G=OK/Y=Atenção/R=Crítico)'.

  " Oculta colunas menos relevantes na visualização inicial
  TRY.
      DATA(lo_c) = CAST cl_salv_column_table( po_columns->get_column( 'AUART' ) ).
      lo_c->set_visible( abap_false ).
    CATCH cx_salv_not_found.
  ENDTRY.

ENDFORM.

*---- Textos de seleção (simulados para referência) -------------------
* TEXT-b01 = 'Parâmetros de Seleção'
* TEXT-b02 = 'Período de Planejamento'
* TEXT-b03 = 'Status das Ordens'
