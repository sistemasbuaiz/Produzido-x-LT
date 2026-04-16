*&---------------------------------------------------------------------*
*&
*& Report  ZPPR014
*&
*&---------------------------------------------------------------------*

REPORT zppr014.

*&---------------------------------------------------------------------*

TABLES: afko, afpo.

*&---------------------------------------------------------------------*

TYPES: BEGIN OF ty_mseg,
         aufnr TYPE aufnr,
         matnr TYPE matnr,
         werks TYPE werks_d,
         menge TYPE menge_d,
       END OF ty_mseg.

TYPES: BEGIN OF ty_afko,
         aufnr  TYPE aufnr,
         pwerk  TYPE werks_d,
         plnbez TYPE matnr,
         igmng  TYPE afko-igmng,
         stlal  TYPE stlal,
         stlan  TYPE stlan,
         stlnr  TYPE stlnr,
       END OF ty_afko.

TYPES: BEGIN OF ty_alv,
         pwerk      TYPE werks_d,
         aufnr      TYPE aufnr,
         plnbez     TYPE matnr,
         idnrk      TYPE matnr,
         menge_real TYPE menge_d,
         menge_plan TYPE menge_d,
         diff       TYPE menge_d,
         color      TYPE lvc_t_scol,
       END OF ty_alv.

*&---------------------------------------------------------------------*

DATA: it_alv  TYPE TABLE OF ty_alv,
      it_mseg TYPE TABLE OF ty_mseg,
      it_afko TYPE TABLE OF ty_afko.

*&---------------------------------------------------------------------*

CLASS lcl_functions DEFINITION.

  PUBLIC SECTION.

    METHODS set_color.

ENDCLASS.

CLASS lcl_functions IMPLEMENTATION.

  METHOD set_color.

    DATA ls_color TYPE lvc_s_scol.

    LOOP AT it_alv ASSIGNING FIELD-SYMBOL(<fs_color>).

      CLEAR ls_color.

      IF <fs_color>-diff IS INITIAL.

        ls_color-fname = 'DIFF'.
        ls_color-color-col = 5.
        ls_color-color-int = 0.
        ls_color-color-inv = 0.
        APPEND ls_color TO <fs_color>-color.

      ELSE.

        ls_color-fname = 'DIFF'.
        ls_color-color-col = 6.
        ls_color-color-int = 0.
        ls_color-color-inv = 0.
        APPEND ls_color TO <fs_color>-color.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.

  SELECT-OPTIONS: s_aufnr FOR afko-aufnr,
                  s_matnr FOR afpo-matnr.

  SELECTION-SCREEN SKIP 1.

  SELECT-OPTIONS: s_gstrp FOR afko-gstrp.

SELECTION-SCREEN END OF BLOCK b01.

*&---------------------------------------------------------------------*

START-OF-SELECTION.

  PERFORM: f_select_data,
           f_show_alv.

*&---------------------------------------------------------------------*
*&      Form  F_SELECT_DATA
*&---------------------------------------------------------------------*

FORM f_select_data.

  " Etapa 1: Movimentos reais na MSEG sem referência de estorno (LFBNR vazio)
  " Documentos com LFBNR preenchido são passivos a estorno e devem ser ignorados
  SELECT aufnr,
         matnr,
         werks,
         SUM( menge ) AS menge
    FROM mseg
    INTO TABLE @it_mseg
    WHERE aufnr IN @s_aufnr
      AND werks  IN ( 'BAMO', 'CDTR', 'CFMA' )
      AND lfbnr  =  @space
    GROUP BY aufnr, matnr, werks.

  IF sy-subrc IS NOT INITIAL OR it_mseg IS INITIAL.
    MESSAGE 'Dados não encontrados na MSEG para esse parâmetro' TYPE 'E' DISPLAY LIKE 'S'.
    STOP.
  ENDIF.

  " Etapa 2: Monta range de ordens únicas a partir dos documentos encontrados na MSEG
  DATA lt_aufnr TYPE RANGE OF aufnr.

  LOOP AT it_mseg ASSIGNING FIELD-SYMBOL(<fs_m>).
    APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_m>-aufnr ) TO lt_aufnr.
  ENDLOOP.

  SORT lt_aufnr BY low.
  DELETE ADJACENT DUPLICATES FROM lt_aufnr COMPARING low.

  " Etapa 3: Busca na AFKO a quantidade confirmada (IGMNG), o material produzido (PLNBEZ)
  "          e os dados da lista técnica vinculada (STLAL, STLAN, STLNR)
  "          O centro vem de AFPO-PWERK pois AFKO não possui campo WERKS
  SELECT DISTINCT a~aufnr,
         b~pwerk,
         a~plnbez,
         a~igmng,
         a~stlal,
         a~stlan,
         a~stlnr
    FROM afko AS a
    INNER JOIN afpo AS b ON a~aufnr = b~aufnr
    INTO TABLE @it_afko
    WHERE a~aufnr  IN @lt_aufnr
      AND a~gstrp  IN @s_gstrp
      AND b~matnr  IN @s_matnr
      AND b~pwerk  IN ( 'BAMO', 'CDTR', 'CFMA' ).

  IF sy-subrc IS NOT INITIAL OR it_afko IS INITIAL.
    MESSAGE 'Dados da ordem não encontrados na AFKO' TYPE 'E' DISPLAY LIKE 'S'.
    STOP.
  ENDIF.

  SORT it_mseg BY aufnr matnr.
  SORT it_afko BY aufnr.

  " Etapa 4: Para cada ordem, explode a LT via CS_BOM_EXPL_MAT_V2
  "          e compara o real (MSEG) com o planejado (LT)
  DATA lt_stb      TYPE TABLE OF stpox.
  DATA lt_matcat   TYPE TABLE OF stpovf.
  DATA lt_mseg_ord TYPE TABLE OF ty_mseg.

  LOOP AT it_afko ASSIGNING FIELD-SYMBOL(<fs_afko>).

    " Filtra componentes consumidos na MSEG para esta ordem
    CLEAR lt_mseg_ord.

    LOOP AT it_mseg ASSIGNING FIELD-SYMBOL(<fs_mseg_all>)
      WHERE aufnr = <fs_afko>-aufnr.
      APPEND <fs_mseg_all> TO lt_mseg_ord.
    ENDLOOP.

    IF lt_mseg_ord IS INITIAL.
      CONTINUE.
    ENDIF.

    SORT lt_mseg_ord BY matnr.

    " Explosão da lista técnica vinculada à ordem
    " Quantidades retornadas já escalonadas pela quantidade confirmada (IGMNG)
    CLEAR: lt_stb, lt_matcat.

    CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
      EXPORTING
        capid                 = 'PP01'
        datuv                 = sy-datum
        mehrs                 = 'X'
        mtnrv                 = <fs_afko>-plnbez
        werks                 = <fs_afko>-pwerk
        stlal                 = <fs_afko>-stlal
        stlan                 = <fs_afko>-stlan
        menge                 = 1
        emeng                 = <fs_afko>-igmng
      TABLES
        stb                   = lt_stb
        matcat                = lt_matcat
      EXCEPTIONS
        alt_not_found         = 1
        call_invalid          = 2
        material_not_found    = 3
        missing_authorization = 4
        no_bom_found          = 5
        no_plant_data         = 6
        no_suitable_bom_found = 7
        conversion_error      = 8
        OTHERS                = 9.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    " Remove itens sem material (texto, variável, etc.)
    DELETE lt_stb WHERE idnrk IS INITIAL.

    SORT lt_stb BY idnrk.

    " Comparação: Componentes apontados na Ordem (MSEG) x Componentes da LT (CS_BOM_EXPL_MAT_V2)
    LOOP AT lt_mseg_ord ASSIGNING FIELD-SYMBOL(<fs_mseg>).

      DATA(ls_alv) = VALUE ty_alv(
        pwerk      = <fs_afko>-pwerk
        aufnr      = <fs_afko>-aufnr
        plnbez     = <fs_afko>-plnbez
        idnrk      = <fs_mseg>-matnr
        menge_real = <fs_mseg>-menge
      ).

      " Localiza o componente na lista técnica para obter a quantidade planejada
      READ TABLE lt_stb ASSIGNING FIELD-SYMBOL(<fs_stb>)
        WITH KEY idnrk = <fs_mseg>-matnr
        BINARY SEARCH.

      IF sy-subrc = 0.
        ls_alv-menge_plan = <fs_stb>-menge.
      ENDIF.

      ls_alv-diff = ls_alv-menge_real - ls_alv-menge_plan.

      APPEND ls_alv TO it_alv.

    ENDLOOP.

    " Componentes previstos na LT que não tiveram consumo registrado na MSEG
    LOOP AT lt_stb ASSIGNING FIELD-SYMBOL(<fs_stb2>).

      READ TABLE lt_mseg_ord TRANSPORTING NO FIELDS
        WITH KEY matnr = <fs_stb2>-idnrk
        BINARY SEARCH.

      IF sy-subrc <> 0.

        APPEND VALUE ty_alv(
          pwerk      = <fs_afko>-pwerk
          aufnr      = <fs_afko>-aufnr
          plnbez     = <fs_afko>-plnbez
          idnrk      = <fs_stb2>-idnrk
          menge_real = 0
          menge_plan = <fs_stb2>-menge
          diff       = 0 - <fs_stb2>-menge
        ) TO it_alv.

      ENDIF.

    ENDLOOP.

  ENDLOOP.

  IF it_alv IS INITIAL.
    MESSAGE 'Nenhum dado encontrado para os parâmetros informados' TYPE 'E' DISPLAY LIKE 'S'.
    STOP.
  ENDIF.

  SORT it_alv BY aufnr idnrk.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_SHOW_ALV
*&---------------------------------------------------------------------*

FORM f_show_alv.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lr_alv)
                              CHANGING t_table = it_alv[] ).
    CATCH cx_root.
      MESSAGE 'Erro na criação do ALV' TYPE 'S' DISPLAY LIKE 'E'.
      STOP.
  ENDTRY.

*&----------------------------------------------------------------------------------------------------------*

  IF lines( it_alv[] ) < 5000. "Cabeçalho

    DATA(lr_header) = NEW cl_salv_form_layout_grid( ).
    lr_header->create_header_information( row = 1 column = 1 text = 'Produzido X LT' ).

    DATA(lr_flow) = lr_header->create_flow( row = 2 column = 1 ).
    lr_flow->create_text( text = '' ).

    lr_flow = lr_header->create_flow( row = 3 column = 1 ).
    lr_flow->create_text( text = |Data: { sy-datum+6(2) }/{ sy-datum+4(2) }/{ sy-datum(4) }| ).

    lr_flow = lr_header->create_flow( row = 4 column = 1 ).
    lr_flow->create_text( text = |Hora: { sy-uzeit(2) }:{ sy-uzeit+2(2) }| ).

    lr_flow = lr_header->create_flow( row = 5 column = 1 ).
    lr_flow->create_text( text = |Total de linhas: { lines( it_alv[] ) }| ).

    DATA(lo_logo) = NEW cl_salv_form_layout_logo( ).
    lo_logo->set_right_logo( 'TRVPICTURE_REC_WIZ04' ).     "TRANSAÇÃO: OAOR - PICTURES OT - Logo Buaiz
    lo_logo->set_left_content( lr_header ).

    lr_alv->set_top_of_list( lo_logo ).

  ENDIF.

*&----------------------------------------------------------------------------------------------------------*

  DATA(lr_display) = lr_alv->get_display_settings( ).
  lr_display->set_striped_pattern( abap_true ).

  DATA(lr_columns) = lr_alv->get_columns( ).
  lr_columns->set_optimize( abap_true ).

*&----------------------------------------------------------------------------------------------------------*

  DATA(lr_functions) = lr_alv->get_functions( ).
  lr_functions->set_all( abap_true ).

*&----------------------------------------------------------------------------------------------------------*

  TRY.
    lr_columns->set_color_column( 'COLOR' ).
  CATCH cx_salv_data_error.
  ENDTRY.

  DATA(lr_events) = lr_alv->get_event( ).

  DATA(lr_event) = NEW lcl_functions( ).
  lr_event->set_color( ).

*&----------------------------------------------------------------------------------------------------------*

  DATA(lr_sorts) = lr_alv->get_sorts( ).

  TRY.
   lr_sorts->add_sort( columnname = 'AUFNR'
                       subtotal   = abap_true  ).
  CATCH cx_root.
  ENDTRY.

*&----------------------------------------------------------------------------------------------------------*

  TRY.

    DATA(lr_column) = CAST cl_salv_column_table( lr_columns->get_column( 'PWERK' ) ).
    lr_column->set_long_text( 'Centro' ).
    lr_column->set_medium_text( 'Centro' ).
    lr_column->set_short_text( 'Centro' ).

    lr_column = CAST cl_salv_column_table( lr_columns->get_column( 'PLNBEZ' ) ).
    lr_column->set_long_text( 'Material Produzido' ).
    lr_column->set_medium_text( 'Mat. Produzido' ).
    lr_column->set_short_text( 'Produzido' ).

    lr_column = CAST cl_salv_column_table( lr_columns->get_column( 'IDNRK' ) ).
    lr_column->set_long_text( 'Componente' ).
    lr_column->set_medium_text( 'Componente' ).
    lr_column->set_short_text( 'Componente' ).

    lr_column = CAST cl_salv_column_table( lr_columns->get_column( 'MENGE_PLAN' ) ).
    lr_column->set_long_text( 'Planejado' ).
    lr_column->set_medium_text( 'Planejado' ).
    lr_column->set_short_text( 'Planejado' ).

    lr_column = CAST cl_salv_column_table( lr_columns->get_column( 'MENGE_REAL' ) ).
    lr_column->set_long_text( 'Real' ).
    lr_column->set_medium_text( 'Real' ).
    lr_column->set_short_text( 'Real' ).

    lr_column = CAST cl_salv_column_table( lr_columns->get_column( 'DIFF' ) ).
    lr_column->set_long_text( 'Diferença' ).
    lr_column->set_medium_text( 'Diferença' ).
    lr_column->set_short_text( 'Diferença' ).

  CATCH cx_root.
  ENDTRY.

*&----------------------------------------------------------------------------------------------------------*

  lr_alv->display( ).

ENDFORM.
