CREATE OR REPLACE PACKAGE ALESSANDRO AS

PROCEDURE nuovaAreaFascia1(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2);
PROCEDURE nuovaAreaFascia2(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2, var_idFascia VARCHAR2);
PROCEDURE modAreaFasciaRis(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_idArea VARCHAR2, var_idFascia VARCHAR2,
  var_costo VARCHAR2, var_tipo VARCHAR2);

PROCEDURE permanenzaNonAbbonati(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
PROCEDURE percentualePrenotazioni(id_Sessione VARCHAR2,  nome VARCHAR2, ruolo VARCHAR2);
PROCEDURE cronologiaAccessi(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
PROCEDURE areeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
PROCEDURE dettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
PROCEDURE autorimessaTipoCarb(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2);
PROCEDURE dettaglioFascia(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2);

PROCEDURE visualizzaAutorimessaTC(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_data VARCHAR2, var_tipo VARCHAR2);
PROCEDURE visualizzaDettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_giorni VARCHAR2);
PROCEDURE visualizzaPermanenza(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2,
  var_anno VARCHAR2, var_tipo VARCHAR2);
PROCEDURE visualizzaPercentuale(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_anno VARCHAR2, var_tipo VARCHAR2);
PROCEDURE visualizzaCronologia(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2 DEFAULT '',
  var_cliente VARCHAR2 DEFAULT '', var_targa VARCHAR2 DEFAULT '', var_dataInizio VARCHAR2, var_dataFine VARCHAR2);
PROCEDURE visualizzaAreeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2);
