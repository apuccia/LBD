--------------------------------------------------------
--  File creato - martedì-dicembre-03-2019   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package ALE
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE "PUCCIA"."ALE" AS    
    PROCEDURE nuovaAreaFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2);
    PROCEDURE inserimentoAreaFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2, 
                                    var_costo1 VARCHAR2, var_costo2 VARCHAR2, var_costo3 VARCHAR2, var_costo4 VARCHAR2,
                                    var_costo5 VARCHAR2, var_costo6 VARCHAR2, var_costo7 VARCHAR2, var_costo8 VARCHAR2, 
                                    var_costo9 VARCHAR2, var_costo10 VARCHAR2, var_costo11 VARCHAR2, var_costo12 VARCHAR2);
    PROCEDURE permanenzaNonAbbonati(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
    PROCEDURE percentualePrenotazioni(id_Sessione VARCHAR2,  nome VARCHAR2, ruolo VARCHAR2);
    PROCEDURE cronologiaAccessi(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
    PROCEDURE areeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
    PROCEDURE dettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
    PROCEDURE dettaglioFascia(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2);
    
    PROCEDURE visualizzaDettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_giorni VARCHAR2);
    PROCEDURE visualizzaPermanenza(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2,
        var_anno VARCHAR2, var_tipo VARCHAR2);
    PROCEDURE visualizzaPercentuale(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_anno VARCHAR2, var_tipo VARCHAR2);
    PROCEDURE visualizzaCronologia(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2 DEFAULT '',
        var_cliente VARCHAR2 DEFAULT '', var_targa VARCHAR2 DEFAULT '', var_dataInizio VARCHAR2, var_dataFine VARCHAR2);
    PROCEDURE visualizzaAreeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2);
END ALE;

/
