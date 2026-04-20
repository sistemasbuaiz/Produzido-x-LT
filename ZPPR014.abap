*&---------------------------------------------------------------------*
*&
*& Report  ZPPR014
*&
*&---------------------------------------------------------------------*

REPORT zppr014.

*&---------------------------------------------------------------------*

TABLES: afko, afpo.

*&---------------------------------------------------------------------*

TYPES: BEGIN OF ty_alv,

         pwerk      TYPE afpo-pwerk,
         aufnr      TYPE aufnr,
         matnr      TYPE matnr,
         idnrk      TYPE matnr,
         menge_real TYPE menge_d,
         menge_plan TYPE menge_d,
         diff       TYPE menge_d,
         color      TYPE lvc_t_scol,

       END OF ty_alv.

*&---------------------------------------------------------------------*

DATA: it_alv TYPE TABLE OF ty_alv.

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

  SELECT a~aufnr,
         b~matnr,
         b~pwerk,
         c~matnr AS idnrk,
         c~bdmng AS menge_plan,
         SUM( d~menge ) AS menge_real
    FROM afko AS a
    INNER JOIN afpo AS b ON a~aufnr = b~aufnr
    INNER JOIN resb AS c ON a~aufnr = c~aufnr
    INNER JOIN mseg AS d ON a~aufnr = d~aufnr AND c~matnr = d~matnr
    INTO CORRESPONDING FIELDS OF TABLE @it_alv
    WHERE a~aufnr IN @s_aufnr
      AND a~gstrp IN @s_gstrp
      AND b~matnr IN @s_matnr
      AND b~pwerk IN ( 'BAMO', 'CDTR', 'CFMA' )
    GROUP BY a~aufnr, b~matnr, b~pwerk, c~matnr, c~bdmng.

  IF sy-subrc IS NOT INITIAL.
    MESSAGE 'Dados não encontrados para esse parâmentro' TYPE 'E' DISPLAY LIKE 'S'.
    STOP.
  ENDIF.

*&---------------------------------------------------------------------*

  LOOP AT it_alv ASSIGNING FIELD-SYMBOL(<fs_alv>).

    <fs_alv>-diff = <fs_alv>-menge_real - <fs_alv>-menge_plan.

  ENDLOOP.

  SORT it_alv BY aufnr.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  F_SHOW_ALV
*&---------------------------------------------------------------------*

FORM f_show_alv.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lr_alv)
                              CHANGING t_table = it_alv[] ).
    CATCH cx_root.
      MESSAGE 'Erro não abribuição do ALV!!' TYPE 'S' DISPLAY LIKE 'E'.
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
    lr_column->set_long_text( 'Centro planejado' ).
    lr_column->set_medium_text( 'Centro plan.' ).
    lr_column->set_short_text( 'Centro' ).

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

  lr_alv->set_top_of_list( lo_logo ).
  lr_alv->display( ).

ENDFORM.
