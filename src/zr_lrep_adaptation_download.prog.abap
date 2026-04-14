*&---------------------------------------------------------------------*
*& Report ZR_LREP_ADAPTATION_DOWNLOAD
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zr_lrep_adaptation_download.

SELECTION-SCREEN BEGIN OF LINE.
  SELECTION-SCREEN COMMENT 1(20) sc_cust FOR FIELD p_cust.
  PARAMETERS p_cust(128) TYPE c OBLIGATORY LOWER CASE.
SELECTION-SCREEN END OF LINE.

CLASS lcl_adaptation_downloader DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_std_app,
             std_app TYPE string,
           END OF ty_std_app,
           tt_std_app TYPE STANDARD TABLE OF ty_std_app WITH EMPTY KEY.

    TYPES: BEGIN OF ty_document,
             namespace TYPE /uif/lrepdcont-namespace,
             name      TYPE /uif/lrepdcont-name,
             type      TYPE /uif/lrepdcont-type,
             content   TYPE xstring,
           END OF ty_document.

    TYPES ty_documents TYPE STANDARD TABLE OF ty_document WITH EMPTY KEY.

    CLASS-METHODS show_f4_help.

    METHODS run
      IMPORTING iv_custom_app TYPE clike.

  PRIVATE SECTION.
    DATA mv_id        TYPE string.
    DATA mv_folder    TYPE string.
    DATA mv_id_length TYPE i.

    METHODS resolve_standard_app
      IMPORTING iv_custom_app TYPE clike
      RETURNING VALUE(rv_std) TYPE string
      RAISING   cx_salv_msg.

    METHODS extract_std_apps
      IMPORTING it_namespaces      TYPE ANY TABLE
      RETURNING VALUE(rt_std_apps) TYPE tt_std_app.

    METHODS select_std_app_popup
      IMPORTING it_std_apps   TYPE tt_std_app
      RETURNING VALUE(rv_std) TYPE string
      RAISING   cx_salv_msg.

    METHODS select_download_folder
      RETURNING VALUE(rv_folder) TYPE string.

    METHODS fetch_documents
      RETURNING VALUE(rt_documents) TYPE ty_documents.

    METHODS download_documents
      IMPORTING it_documents    TYPE ty_documents
      RETURNING VALUE(rv_count) TYPE i.

    METHODS build_target_path
      IMPORTING iv_namespace   TYPE clike
      RETURNING VALUE(rv_path) TYPE string.

ENDCLASS.


CLASS lcl_adaptation_downloader IMPLEMENTATION.
  METHOD run.
    DATA lv_std TYPE string.

    TRY.
        lv_std = resolve_standard_app( iv_custom_app ).
      CATCH cx_salv_msg.
        MESSAGE 'Error displaying selection popup.' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    IF lv_std IS INITIAL.
      RETURN.
    ENDIF.

    mv_id = |apps/{ lv_std }/appVariants/{ iv_custom_app }|.
    mv_id_length = strlen( mv_id ).

    mv_folder = select_download_folder( ).
    IF mv_folder IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_documents) = fetch_documents( ).
    IF lt_documents IS INITIAL.
      MESSAGE 'No records found.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(lv_count) = download_documents( lt_documents ).

    MESSAGE |{ lv_count } file(s) saved to { mv_folder }| TYPE 'S'.
  ENDMETHOD.

  METHOD resolve_standard_app.
    DATA lv_pattern TYPE string.

    lv_pattern = |apps/%/appVariants/{ iv_custom_app }%|.

    SELECT DISTINCT namespace FROM /uif/lrepdcont
      INTO TABLE @DATA(lt_namespaces)
      WHERE namespace  LIKE @lv_pattern
        AND layer_type    = 'CUSTOMER_BASE'.

    IF sy-subrc <> 0 OR lt_namespaces IS INITIAL.
      MESSAGE 'No records found for the given custom app.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(lt_std_apps) = extract_std_apps( lt_namespaces ).

    IF lt_std_apps IS INITIAL.
      MESSAGE 'Could not determine standard app.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF lines( lt_std_apps ) = 1.
      rv_std = lt_std_apps[ 1 ]-std_app.
    ELSE.
      rv_std = select_std_app_popup( lt_std_apps ).
    ENDIF.
  ENDMETHOD.

  METHOD extract_std_apps.
    DATA lv_after     TYPE string.
    DATA lv_pos       TYPE i.
    DATA lv_std_entry TYPE string.

    FIELD-SYMBOLS <ls_ns> TYPE any.

    LOOP AT it_namespaces ASSIGNING <ls_ns>.
      ASSIGN COMPONENT 'NAMESPACE' OF STRUCTURE <ls_ns> TO FIELD-SYMBOL(<lv_ns>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      lv_after = <lv_ns>.
      IF strlen( lv_after ) <= 5.
        CONTINUE.
      ENDIF.

      lv_after = lv_after+5.
      lv_pos = find( val = lv_after
                     sub = '/appVariants/' ).
      IF lv_pos > 0.
        lv_std_entry = lv_after(lv_pos).
        IF NOT line_exists( rt_std_apps[ std_app = lv_std_entry ] ).
          APPEND VALUE #( std_app = lv_std_entry ) TO rt_std_apps.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD select_std_app_popup.
    DATA lt_display    TYPE STANDARD TABLE OF ty_std_app WITH EMPTY KEY.
    DATA lo_salv       TYPE REF TO cl_salv_table.
    DATA lo_selections TYPE REF TO cl_salv_selections.

    lt_display = it_std_apps.

    cl_salv_table=>factory( IMPORTING r_salv_table = lo_salv
                            CHANGING  t_table      = lt_display ).

    lo_salv->set_screen_popup( start_column = 10
                               end_column   = 90
                               start_line   = 5
                               end_line     = 15 ).

    lo_selections = lo_salv->get_selections( ).
    lo_selections->set_selection_mode( if_salv_c_selection_mode=>single ).

    lo_salv->display( ).

    DATA(lt_rows) = lo_selections->get_selected_rows( ).

    IF lt_rows IS INITIAL.
      MESSAGE 'No standard app selected.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    rv_std = lt_display[ lt_rows[ 1 ] ]-std_app.
  ENDMETHOD.

  METHOD select_download_folder.
    cl_gui_frontend_services=>directory_browse( EXPORTING  window_title    = 'Select Download Folder'
                                                CHANGING   selected_folder = rv_folder
                                                EXCEPTIONS OTHERS          = 1 ).

    IF sy-subrc <> 0 OR rv_folder IS INITIAL.
      MESSAGE 'No folder selected.' TYPE 'S' DISPLAY LIKE 'E'.
      CLEAR rv_folder.
    ENDIF.
  ENDMETHOD.

  METHOD fetch_documents.
    DATA lv_namespace TYPE string.

    lv_namespace = |{ mv_id }%|.

    SELECT namespace, name, type, content
      FROM /uif/lrepdcont
      INTO TABLE @rt_documents
      WHERE namespace  LIKE @lv_namespace
        AND layer_type    = 'CUSTOMER_BASE'.
  ENDMETHOD.

  METHOD download_documents.
    DATA lt_binary   TYPE solix_tab.
    DATA lv_length   TYPE i.
    DATA lv_target   TYPE string.
    DATA lv_rc       TYPE i.
    DATA lv_filename TYPE string.
    DATA lv_count    TYPE i.

    LOOP AT it_documents INTO DATA(ls_doc).
      IF ls_doc-content IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR: lt_binary,
             lv_length.

      lv_target = build_target_path( ls_doc-namespace ).

      cl_gui_frontend_services=>directory_create( EXPORTING  directory = lv_target
                                                  CHANGING   rc        = lv_rc
                                                  EXCEPTIONS OTHERS    = 1 ).

      CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
        EXPORTING buffer        = ls_doc-content
        IMPORTING output_length = lv_length
        TABLES    binary_tab    = lt_binary.

      lv_filename = |{ lv_target }\\{ ls_doc-name }.{ ls_doc-type }|.

      cl_gui_frontend_services=>gui_download( EXPORTING  filename     = lv_filename
                                                         filetype     = 'BIN'
                                                         bin_filesize = lv_length
                                              CHANGING   data_tab     = lt_binary
                                              EXCEPTIONS OTHERS       = 1 ).

      IF sy-subrc = 0.
        lv_count = lv_count + 1.
      ENDIF.
    ENDLOOP.

    rv_count = lv_count.
  ENDMETHOD.

  METHOD build_target_path.
    DATA lv_subpath TYPE string.

    lv_subpath = iv_namespace.

    IF strlen( lv_subpath ) > mv_id_length.
      lv_subpath = lv_subpath+mv_id_length.
      SHIFT lv_subpath LEFT DELETING LEADING '/'.
    ELSE.
      CLEAR lv_subpath.
    ENDIF.

    REPLACE ALL OCCURRENCES OF '/' IN lv_subpath WITH '\'.

    IF lv_subpath IS NOT INITIAL.
      rv_path = |{ mv_folder }\\{ lv_subpath }|.
    ELSE.
      rv_path = mv_folder.
    ENDIF.
  ENDMETHOD.

  METHOD show_f4_help.
    TYPES: BEGIN OF lty_data,
             id    TYPE /ui5/app_var_id,
             title TYPE /ui5/descr_title,
           END OF lty_data.

    DATA lo_app_index_srch    TYPE REF TO /ui5/if_ui5_app_index_search.
    DATA lt_params            TYPE name2stringvalue_table.
    DATA lt_requested_columns TYPE string_table.
    DATA lt_data              TYPE TABLE OF lty_data.
    DATA lt_return            TYPE STANDARD TABLE OF ddshretval.
    DATA lt_update            TYPE STANDARD TABLE OF rsselread.

    FIELD-SYMBOLS <result_tab> TYPE STANDARD TABLE.

    lo_app_index_srch ?= /ui5/cl_ui5_app_api_factory=>get_app_index_instance( ).

    APPEND VALUE #( name  = /ui5/if_ui5_app_index_search=>cv_field_file_type
                    value = 'appdescr_variant' ) TO lt_params.
    APPEND VALUE #( name  = /ui5/if_ui5_app_index_search=>cv_field_origin_layer
                    value = 'CUSTOMER_BASE' ) TO lt_params.

    APPEND /ui5/if_ui5_app_index_search=>cv_int_field_id TO lt_requested_columns.
    APPEND /ui5/if_ui5_app_index_search=>cv_int_field_title TO lt_requested_columns.

    DATA(lr_result) = lo_app_index_srch->search( it_params            = lt_params
                                                 it_requested_columns = lt_requested_columns ).

    ASSIGN lr_result->* TO <result_tab>.

    LOOP AT <result_tab> ASSIGNING FIELD-SYMBOL(<entry>).
      ASSIGN COMPONENT /ui5/if_ui5_app_index_search=>cv_int_field_id OF STRUCTURE <entry> TO FIELD-SYMBOL(<id>).
      ASSIGN COMPONENT /ui5/if_ui5_app_index_search=>cv_int_field_title OF STRUCTURE <entry> TO FIELD-SYMBOL(<title>).
      IF sy-subrc = 0.
        INSERT VALUE #( id    = CONV #( <id> )
                        title = CONV #( <title> ) ) INTO TABLE lt_data.
      ENDIF.
    ENDLOOP.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING  retfield        = 'ID'
                 window_title    = 'Select Custom App'
                 value_org       = 'S'
      TABLES     value_tab       = lt_data
                 return_tab      = lt_return
      EXCEPTIONS parameter_error = 1
                 no_values_found = 2
                 OTHERS          = 3 ##FM_SUBRC_OK.

    IF lt_return IS NOT INITIAL.
      lt_update = VALUE #( ( kind = 'P' name = 'P_CUST' fieldvalue = lt_return[ 1 ]-fieldval ) ).
      CALL FUNCTION 'RS_SELECTIONSCREEN_UPDATE'
        EXPORTING program      = sy-repid
        TABLES    updatevalues = lt_update.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_cust.
  lcl_adaptation_downloader=>show_f4_help( ).

INITIALIZATION.
  sc_cust = 'Custom App ID'.

START-OF-SELECTION.
  NEW lcl_adaptation_downloader( )->run( p_cust ).
