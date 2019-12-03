--------------------------------------------------------
--  File creato - martedì-dicembre-03-2019   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Package Body ALE
--------------------------------------------------------

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PUCCIA"."ALE" AS
    TYPE array_int IS VARRAY(12) OF INTEGER;
    TYPE rec_prenot IS RECORD (
        var_numPrenotazione INTEGER,
        var_numSenzaPrenotazione INTEGER,
        var_totale INTEGER,
        var_percentuale NUMBER(5,2)
    );
    
    exc_noAutorimessa EXCEPTION;
    exc_noCliente EXCEPTION;
    exc_noTarga EXCEPTION;
    exc_dataNulla EXCEPTION;
    exc_noTipo EXCEPTION;
    exc_noArea EXCEPTION;
    exc_errCosto EXCEPTION;
    
    FUNCTION checkAutorimessa(var_autorimessa VARCHAR2) RETURN BOOLEAN IS
        var_contaAutorimessa INTEGER;
    BEGIN
        SELECT COUNT(idAutorimessa) INTO var_contaAutorimessa
        FROM Autorimesse
        WHERE indirizzo = var_autorimessa;
        
        RETURN var_contaAutorimessa = 1;
    END checkAutorimessa;
    
    FUNCTION checkCliente(var_cliente VARCHAR2) RETURN BOOLEAN IS
        var_contaCliente INTEGER;
    BEGIN
        SELECT COUNT(idCliente) INTO var_contaCliente
        FROM Clienti
        INNER JOIN Persone ON clienti.idPersona = persone.idPersona
        WHERE codiceFiscale = var_cliente;
        
        RETURN var_contaCliente = 1;
    END checkCliente;
    
    FUNCTION checkTarga(var_targa VARCHAR2) RETURN BOOLEAN IS
        var_contaTarga INTEGER;
    BEGIN
        SELECT COUNT(idVeicolo) INTO var_contaTarga
        FROM Veicoli
        WHERE targa = var_targa;
        
        RETURN var_contaTarga = 1;
    END checkTarga;
    
    FUNCTION checkArea(var_idArea VARCHAR2) RETURN BOOLEAN IS
        var_contaArea INTEGER;
    BEGIN
        SELECT COUNT(*) INTO var_contaArea
        FROM aree
        WHERE aree.idArea = var_idArea;
        
        RETURN var_contaArea = 1;
    END checkArea;
    -- converte il timestamp ricevuto in input in secondi, considerando l'ora, i minuti e i secondi.
    FUNCTION convertiOraInSecondi(var_ora TIMESTAMP) RETURN INTEGER IS
    BEGIN
        RETURN (EXTRACT(HOUR FROM var_ora) * 3600) +
               (EXTRACT(MINUTE FROM var_ora) * 60) + 
                EXTRACT(SECOND FROM var_ora);
    END convertiOraInSecondi;
    
    -- Calcola la percentuale di ingressi con prenotazione dal punto di vista del cliente
    FUNCTION calcoloInfoPrenotCliente(var_idcliente VARCHAR2, var_anno VARCHAR2) RETURN rec_prenot IS
        prova INTEGER;
        infoPrenotazioni rec_prenot;
    BEGIN
        SELECT COUNT(ingressiorari.entrataprevista), COUNT(*), AVG(COUNT(ingressiorari.entrataprevista)) * 100
            INTO infoPrenotazioni.var_numPrenotazione, infoPrenotazioni.var_totale, infoPrenotazioni.var_percentuale
        FROM ingressiorari
        INNER JOIN effettuaingressiorari ON ingressiorari.idingressoorario = effettuaingressiorari.idingressoorario
        WHERE effettuaingressiorari.idcliente = var_idcliente AND (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT(YEAR FROM orauscita) = var_anno)
        GROUP BY ingressiorari.entrataprevista;
        
        infoPrenotazioni.var_numSenzaPrenotazione := infoPrenotazioni.var_totale - infoPrenotazioni.var_numPrenotazione;
        
        RETURN infoPrenotazioni;
    END calcoloInfoPrenotCliente;
    
    -- Calcola la percentuale di ingressi con prenotazione dal punto di vista dell'autorimessa
    FUNCTION calcoloInfoPrenotAutorim(var_idAutorimessa VARCHAR2, var_anno VARCHAR2) RETURN rec_prenot IS
        infoPrenotazioni rec_prenot;
    BEGIN
        SELECT COUNT(entrataPrevista), COUNT(*), AVG(COUNT(entrataprevista)) * 100
            INTO infoPrenotazioni.var_numPrenotazione, infoPrenotazioni.var_totale, infoPrenotazioni.var_percentuale
        FROM ingressiOrari
        INNER JOIN box ON ingressiOrari.idBox = box.idBox
        INNER JOIN aree ON box.idArea = aree.idArea
        INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
        WHERE autorimesse.idAutorimessa = var_idAutorimessa AND (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT(YEAR FROM orauscita) = var_anno)
        GROUP BY ingressiOrari.entrataPrevista;
        
        infoPrenotazioni.var_numSenzaPrenotazione := infoPrenotazioni.var_totale - infoPrenotazioni.var_numPrenotazione;
        
        RETURN infoPrenotazioni;
    END calcoloInfoPrenotAutorim;
    
    FUNCTION calcoloTempoMese(var_autorimessa VARCHAR2, var_anno INTEGER) RETURN array_int IS
        -- calcola il tempo medio di permanenza degli ingressi, secondo le fasce orarie, che sono stati fatti in una determinata 
        -- autorimessa e in un lasso di tempo che include l'anno passato come input
        CURSOR cur_ingressi IS
            SELECT oraentrata, orauscita
            FROM ingressiorari
            INNER JOIN box ON ingressiorari.idbox = box.idbox
            INNER JOIN aree ON box.idarea = aree.idarea
            INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL AND autorimesse.indirizzo = var_autorimessa
                AND (var_anno = EXTRACT(YEAR FROM oraentrata) OR var_anno = EXTRACT(YEAR FROM orauscita));

        row_ingressi cur_ingressi%ROWTYPE;
    
        var_calcoloSecondi array_int := array_int();
        var_contatoriIngressi array_int := array_int();
    
        var_annoEntrata INTEGER;
        var_annoUscita INTEGER;
    
        var_meseEntrata INTEGER;
        var_meseUscita INTEGER;
    
        var_ultimoGiorno DATE;
        var_primoGiorno DATE;
    BEGIN
        FOR i IN 1..12
        LOOP
            var_calcoloSecondi.extend();
            var_calcoloSecondi(i) := 0;
            
            var_contatoriIngressi.extend();
            var_contatoriIngressi(i) := 0;
        END LOOP;
    
        FOR row_ingressi IN cur_ingressi
        LOOP
            var_annoEntrata := EXTRACT(YEAR FROM row_ingressi.oraEntrata);
            var_annoUscita := EXTRACT(YEAR FROM row_ingressi.oraUscita);
            
            
            IF var_annoEntrata = var_annoUscita THEN
                -- caso in cui l'ingresso e l'uscita sono nello stesso anno
                
                var_meseEntrata := EXTRACT(MONTH FROM row_ingressi.oraEntrata);
                var_meseUscita := EXTRACT(MONTH FROM row_ingressi.oraUscita);
                
                IF var_meseEntrata != var_meseUscita THEN
                    -- caso in cui l'ingresso e l'uscita sono in mesi diversi
                    
                    -- ottengo il primo giorno del mese di uscita
                    var_primoGiorno := TRUNC(row_ingressi.oraUscita , 'MM');
                    -- ottengo l'ultimo giorno del mese di ingresso
                    var_ultimoGiorno := TO_DATE(TO_CHAR((LAST_DAY(CAST(row_ingressi.oraEntrata AS DATE))),
                                            'DD-MON-RR') || ' 23:59:59', 'DD-MON-RR HH24:MI:SS');
                    
                    FOR i IN var_meseEntrata .. var_meseUscita
                    LOOP
                        -- scorro tra i mesi di permanenza per calcolare i tempi
                        
                        IF i = var_meseEntrata THEN
                            -- sono nel mese in cui il cliente entra
                            var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                                ((var_ultimoGiorno - CAST(row_ingressi.oraentrata AS DATE)) * 86400);
                        ELSIF i = var_meseUscita THEN
                            -- sono nel mese in cui il cliente esce
                            var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                                ((CAST(row_ingressi.orauscita AS DATE) - var_primoGiorno) * 86400);
                        ELSE
                            -- tutti i mesi nel mezzo
                            var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                                (CAST(TO_CHAR(LAST_DAY(TO_DATE(i, 'MM')),'DD') AS INT) * 86400);
                        END IF;
        
                        var_contatoriIngressi(i) := var_contatoriIngressi(i) + 1;
                    END LOOP;
                ELSE
                    -- caso in cui l'ingresso e l'uscita sono nello stesso mese
                    var_calcoloSecondi(var_meseEntrata) := var_calcoloSecondi(var_meseEntrata) +
                        ((CAST(row_ingressi.orauscita AS DATE) - CAST(row_ingressi.oraentrata AS DATE)) * 86400);
                    var_contatoriIngressi(var_meseEntrata) := var_contatoriIngressi(var_meseEntrata) + 1;
                END IF;
            ELSIF var_annoEntrata = var_anno THEN
                -- caso in cui l'entrata e l'uscita son in 2 anni diversi, "spezzo" l'ingresso considerando solo l'anno di entrata
                
                var_meseEntrata := EXTRACT(MONTH FROM row_ingressi.oraEntrata);
                var_meseUscita := 12;
                
                -- ottengo l'ultimo giorno del mese di ingresso
                var_ultimoGiorno := TO_DATE(TO_CHAR((LAST_DAY(CAST(row_ingressi.oraentrata AS DATE))),
                                                    'DD-MON-RR') || ' 23:59:59', 'DD-MON-RR HH24:MI:SS');
                
                FOR i IN var_meseEntrata .. var_meseUscita
                LOOP
                    -- scorro tra i mesi di permanenza per calcolare i tempi
                    
                    IF i = var_meseEntrata THEN
                        -- sono nel mese in cui il cliente entra
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            ((var_ultimoGiorno - CAST(row_ingressi.oraentrata AS DATE)) * 86400);
                    ELSE
                        -- tutti gli altri mesi
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            (CAST(TO_CHAR(LAST_DAY(TO_DATE(i, 'MM')),'DD') AS INT) * 86400);
                    END IF;
    
                    var_contatoriIngressi(i) := var_contatoriIngressi(i) + 1;
                END LOOP;
            ELSIF var_annoUscita = var_anno THEN
                -- caso in cui l'entrata e l'uscita son in 2 anni diversi, "spezzo" l'ingresso considerando solo l'anno di uscita
                var_meseEntrata := 1;
                var_meseUscita := EXTRACT(MONTH FROM row_ingressi.orauscita);
                
                -- ottengo il primo giorno del mese di uscita
                var_primoGiorno := TRUNC(row_ingressi.orauscita , 'MM');
                
                FOR i IN var_meseEntrata .. var_meseUscita
                LOOP
                    -- scorro tra i vari mesi di permanenza per calcolare i tempi
                    
                    IF i = var_meseUscita THEN
                        -- sono nel mese in cui il cliente esce
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            ((CAST(row_ingressi.orauscita AS DATE) - var_primoGiorno) * 86400);
                    ELSE
                        -- tutti gli altri mesi
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            (CAST(TO_CHAR(LAST_DAY(TO_DATE(i, 'MM')),'DD') AS INT) * 86400);
                    END IF;
    
                    var_contatoriIngressi(i) := var_contatoriIngressi(i) + 1;
                END LOOP;
            END IF;
        END LOOP;
        
        /*FOR i IN 1..12
        LOOP
            -- calcolo la media per ogni mese rispetto al numero di ingressi di quel mese (con e senza prenotazione)
            IF (var_contatoriIngressi(i) != 0) THEN
                var_calcoloSecondi(i) := TRUNC(var_calcoloSecondi(i) / var_contatoriIngressi(i));
            END IF;
        END LOOP;*/
        
        RETURN var_calcoloSecondi;
    END calcoloTempoMese;
    
    FUNCTION calcoloTempoFascia(var_autorimessa VARCHAR2, var_anno VARCHAR2) RETURN array_int IS
        -- calcola il tempo medio di permanenza degli ingressi, secondo i mesi, che sono stati fatti in una determinata autorimessa
        -- e in un lasso di tempo che include l'anno passato come input
        CURSOR cur_ingressi IS
        SELECT oraentrata, orauscita
            FROM ingressiorari
            INNER JOIN box ON ingressiorari.idbox = box.idbox
            INNER JOIN aree ON box.idarea = aree.idarea
            INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL  AND autorimesse.indirizzo = var_autorimessa
                AND (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT(YEAR FROM orauscita) = var_anno);
        
        -- contiene le fasce che sono valide per il giorno che si sta considerando al momento
        CURSOR cur_fasce IS
        SELECT fasceorarie.idfasciaoraria, fasceorarie.nome, orainizio, orafine, giorno
        FROM fasceorarie;
                                        
        row_fasce cur_fasce%ROWTYPE; 
        
        row_ingressi cur_ingressi%ROWTYPE;
        
        var_calcoloSecondi array_int := array_int();
        var_contatoriIngressi array_int := array_int();
    
        var_annoEntrata INTEGER;
        var_annoUscita INTEGER;
    
        var_oraEntrata INTEGER;
        var_oraUscita INTEGER;
        var_oraInizioFascia INTEGER;
        var_oraFineFascia INTEGER;
        
        var_giorni INTEGER;
        var_giornoCorrente TIMESTAMP;
        var_numerofasce INTEGER;
    BEGIN
        SELECT count(*) INTO var_numerofasce FROM fasceorarie;
        
        FOR i IN 1..var_numerofasce
        LOOP
            var_calcoloSecondi.extend();
            var_calcoloSecondi(i) := 0;
            
            var_contatoriIngressi.extend();
            var_contatoriIngressi(i) := 0;
        END LOOP;
        
        FOR row_ingressi IN cur_ingressi
        LOOP
            var_giornoCorrente := row_ingressi.oraEntrata;
            var_annoEntrata := EXTRACT(YEAR FROM row_ingressi.oraEntrata);
            var_annoUscita := EXTRACT(YEAR FROM row_ingressi.oraUscita); 
                
            IF var_annoEntrata = var_annoUscita THEN
                -- sono nel caso in cui l'entrata e l'uscita avvengono nello stesso anno
                var_giorni := TO_DATE(TO_CHAR(row_ingressi.oraUscita, 'DD-MON-RR'), 'DD-MON-RR') - 
                        TO_DATE(TO_CHAR(row_ingressi.oraEntrata, 'DD-MON-RR'), 'DD-MON-RR');
            ELSIF var_annoEntrata = var_anno THEN
                -- sono nel caso in cui l'entrata e l'uscita avvengono in anni diversi, l'anno da considerare è quello di
                -- entrata
                dbms_output.put_line('anno: ' || var_anno);
                var_giorni := TO_DATE('31-DIC-' || var_anno, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian') -
                        TO_DATE(TO_CHAR(row_ingressi.oraEntrata, 'DD-MON-RR'), 'DD-MON-RR');
            ELSIF var_annoUscita = var_anno THEN
                -- sono nel caso in cui l'entrata e l'uscita avvengono in anni diversi, l'anno da considerare è quello di
                -- uscita
                
                dbms_output.put_line('anno: ' || var_anno);
                var_giorni := TO_DATE(TO_CHAR(row_ingressi.oraUscita, 'DD-MON-RR'), 'DD-MON-RR') - 
                        TO_DATE('1-GEN-' || var_anno, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian');
            END IF;
            
            dbms_output.put_line('giorni: ' || var_giorni);
            
            FOR i IN 0 .. var_giorni
            LOOP
                -- scorro tra tutti i giorni di permanenza
                
                    IF var_giorni = 0 THEN
                        -- caso in cui l'entrata e l'uscita avvengono nello stesso giorno
                        var_oraEntrata := 0;
                        var_oraUscita := convertiOraInSecondi(row_ingressi.oraUscita);
                    ELSIF i = 0 AND var_annoEntrata = var_anno THEN
                        -- caso in cui l'entrata e l'uscita avvengono in giorni diversi, sto considerando il primo giorno
                        var_oraEntrata := convertiOraInSecondi(row_ingressi.oraentrata);
                        var_oraUscita := 86400;
                    ELSIF i = var_giorni AND var_annoUscita = var_anno THEN
                        -- caso in cui l'entrata e l'uscita avvengono in giorni diversi, sto considerando l'ultimo giorno
                        var_oraEntrata := 0;
                        var_oraUscita := convertiOraInSecondi(row_ingressi.orauscita);
                    ELSE
                        -- caso in cui l'entrata e l'uscita avvengono in giorni diversi, sto considerando il giorno nel mezzo
                        var_oraEntrata := 0;
                        var_oraUscita := 86400;
                    END IF;
                                    
                    FOR row_fasce IN cur_fasce
                    LOOP
                        -- scorro tra tutte le fasce valide per quel determinato giorno
                        IF row_fasce.giorno = TO_CHAR(var_giornoCorrente, 'DY', 'NLS_DATE_LANGUAGE = italian') THEN
                            var_oraInizioFascia := convertiOraInSecondi(row_fasce.oraInizio);
                            var_oraFineFascia := convertiOraInSecondi(row_fasce.oraFine);
                                       
                            IF (var_oraEntrata >= var_oraInizioFascia AND var_oraUscita <= var_oraFineFascia) THEN
                                -- caso in cui l'entrata e l'uscita avvengono nella stessa fascia oraria
                                var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria)
                                    + var_oraUscita - var_oraEntrata;
                                    
                                var_contatoriIngressi(row_fasce.idfasciaoraria) := var_contatoriIngressi(row_fasce.idfasciaoraria) + 1;
                            ELSIF (var_oraEntrata >= var_oraInizioFascia AND var_oraEntrata <= var_oraFineFascia) THEN
                                -- caso in cui l'entrata avviene in una fascia oraria diversa da quella di uscita
                                var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria)
                                    + var_oraFineFascia - var_oraEntrata;
                                    
                                var_contatoriIngressi(row_fasce.idfasciaoraria) := var_contatoriIngressi(row_fasce.idfasciaoraria) + 1;
                            ElSIF (var_oraUscita >= var_oraInizioFascia AND var_oraUscita <= var_oraFineFascia) THEN
                                -- caso in cui l'uscita avviene in una fascia oraria diversa da quella di entrata
                                var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria)
                                    + var_oraUscita - var_oraInizioFascia;
                                    
                                var_contatoriIngressi(row_fasce.idfasciaoraria) := var_contatoriIngressi(row_fasce.idfasciaoraria) + 1;
                            ELSE
                                EXIT;
                            END IF;
                        END IF;
                    END LOOP;
                
                -- avanzo di un giorno
                var_giornoCorrente := var_giornoCorrente + INTERVAL '1' DAY;    
            END LOOP;
        END LOOP;
        
        FOR i IN 1 .. var_numerofasce
        LOOP
            -- calcolo la media rispetto agli ingressi che si sono avuti in quella fascia
            IF (var_contatoriIngressi(i) != 0) THEN
                var_calcoloSecondi(i) := TRUNC(var_calcoloSecondi(i) / var_contatoriIngressi(i));
            END IF;
            dbms_output.put_line('media in secondi: ' || var_calcoloSecondi(i));
        END LOOP;
            
        RETURN var_calcoloSecondi;
    END calcoloTempoFascia;
  
    PROCEDURE dettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
    BEGIN
        modGUI.apriPagina('HoC | Dettagli giorni', id_Sessione, nome, ruolo);
        
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('DETTAGLI GIORNI');
        modGUI.chiudiIntestazione(2);
        
        modGUI.apriForm('ale.visualizzaDettagliXGiorni');
        
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        modGUI.inserisciInput('var_giorni', 'Giorni', 'number', true);
        
        modGUI.inserisciBottoneReset;
        modGUI.inserisciBottoneForm('SUBMIT');
        modGUI.chiudiForm;
        
        modGUI.chiudiDiv;
        
        modGUI.chiudiPagina;
    END dettagliXGiorni;
  
    PROCEDURE permanenzaNonAbbonati(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
        -- contiene tutte le autorimesse
        CURSOR cur_autorimesse IS
            SELECT indirizzo
            FROM autorimesse;
        
        -- contiene gli anni in cui si sono avuti ingressi
        CURSOR cur_anni IS
            SELECT DISTINCT EXTRACT(YEAR FROM oraentrata) AS anno
            FROM ingressiorari
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
                UNION 
            SELECT DISTINCT EXTRACT(YEAR FROM orauscita) AS anno
            FROM ingressiOrari
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
            ORDER BY anno;
        
        row_autorimesse cur_autorimesse%ROWTYPE;
        row_anni cur_anni%ROWTYPE;
        
    BEGIN
        modGUI.apriPagina('HoC | Statistiche permanenza', id_Sessione, nome, ruolo);
        modGUI.aCapo;
        modGUI.apriDiv;
       
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('TEMPO MEDIO PERMANENZA NON ABBONATI');
        modGUI.chiudiIntestazione(2);    
    
        modgui.apriForm('ale.visualizzaPermanenza'); 
    
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
    
        modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
            FOR row_autorimesse IN cur_autorimesse
            LOOP
                modGUI.inserisciOpzioneSelect(row_autorimesse.indirizzo, row_autorimesse.indirizzo);
            END LOOP;
        modGUI.chiudiSelect;
        
        modGUI.apriSelect('var_anno', 'ANNO');
            FOR row_anni IN cur_anni
            LOOP
                modGUI.inserisciOpzioneSelect(row_anni.anno, row_anni.anno, false);
            END LOOP;
        modGUI.chiudiSelect;
        
        modGUI.inserisciTesto('MEDIA PER:');
        modGUI.aCapo;
        modGUI.inserisciRadioButton('MESE', 'var_tipo', '0', true);
        modGUI.inserisciRadioButton('FASCIA ORARIA', 'var_tipo', '1', false);
        modGUI.inserisciRadioButton('UTENTE', 'var_tipo', '2', false);
        
        modGUI.inserisciBottoneReset;
        modGUI.inserisciBottoneForm('SUBMIT');
        modGUI.chiudiForm;
        
        modGUI.chiudiDiv;
        modGUI.aCapo;
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        modGUI.chiudiPagina;
    
    END permanenzaNonAbbonati;
 
    PROCEDURE areeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
        CURSOR cur_autorimesse IS
            SELECT autorimesse.indirizzo 
            FROM autorimesse;
            
        row_autorimessa cur_autorimesse%ROWTYPE;
    BEGIN
        dbms_output.put_line('adsf');
        modGUI.apriPagina('HoC | Visualizza Aree x Fasce', id_Sessione, nome, ruolo);
        
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('Visualizza Aree x Fasce');
        modGUI.chiudiIntestazione(2);
        
        modGUI.apriForm('ale.visualizzaAreeFasce');
        
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
        modGUI.inserisciOpzioneSelect('', '-- Tutte le autorimesse --');
        FOR row_autorimessa IN cur_autorimesse
        LOOP
            modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
        END LOOP;
        modGUI.chiudiSelect;
            
        modGUI.inserisciBottoneForm('SUBMIT');
            
        modGUI.chiudiForm;
            
        modGUI.chiudiDiv;
        modGUI.aCapo;
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        modGUI.chiudiPagina;
    END;
    
    PROCEDURE nuovaAreaFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2) is
        CURSOR cur_fasce IS
        SELECT fasceorarie.idfasciaoraria, fasceorarie.nome
            FROM fasceorarie
            ORDER BY CASE
                WHEN giorno = 'LUN' THEN 1
                WHEN giorno = 'MAR' THEN 2
                WHEN giorno = 'MER' THEN 3
                WHEN giorno = 'GIO' THEN 4
                WHEN giorno = 'VEN' THEN 5
                WHEN giorno = 'SAB' THEN 6
                WHEN giorno = 'DOM' THEN 7
              END, orainizio ASC;
        
        var_autorimessa VARCHAR2(100);
    BEGIN
        modGUI.apriPagina('HoC | Inserimento nuova associazione', id_Sessione, nome, ruolo);
        
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('INSERIMENTO NUOVA ASSOCIAZIONE');
        modGUI.chiudiIntestazione(2);
        
        SELECT indirizzo INTO var_autorimessa
        FROM aree 
        INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
        WHERE aree.idArea = idRiga;
        
        modGUI.apriIntestazione(3);
            modGUI.inserisciTesto('AUTORIMESSA: ');
            modGUI.collegamento(var_autorimessa, 'link');
            modGUI.aCapo;
            modGUI.inserisciTesto('AREA: ');
            modGUI.collegamento(idRiga, 'link');
        modGUI.chiudiIntestazione(3);
        
        modGUI.apriForm('#');
        
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        FOR row_fasce IN cur_fasce
        LOOP
            modGUI.inserisciTesto(row_fasce.nome);
            modGUI.inserisciInput('var_costo' || row_fasce.idFasciaOraria, 'Costo', 'number', true);
        END LOOP;
        
        modGUI.inserisciBottoneReset('RESET');
        modGUI.inserisciBottoneForm('SUBMIT');
        
        modGUI.chiudiForm;
        modGUI.chiudiDiv;
        modGUI.aCapo;
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END nuovaAreaFasce;
    
    PROCEDURE inserimentoAreaFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2, 
                                    var_costo1 VARCHAR2, var_costo2 VARCHAR2, var_costo3 VARCHAR2, var_costo4 VARCHAR2,
                                    var_costo5 VARCHAR2, var_costo6 VARCHAR2, var_costo7 VARCHAR2, var_costo8 VARCHAR2, 
                                    var_costo9 VARCHAR2, var_costo10 VARCHAR2, var_costo11 VARCHAR2, var_costo12 VARCHAR2) IS
        exc_assocArea EXCEPTION;
    BEGIN
        modGUI.apriPagina('HoC | Inserimento associazione areaXfasce', id_Sessione, nome, ruolo);
    
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('INSERIMENTO ASSOCIAZIONE AREAXFASCE');
        modGUI.chiudiIntestazione(2);
        
        IF idRiga IS NULL OR NOT checkArea(idRiga) THEN
            RAISE exc_noArea;
        END IF;
        
        DECLARE
            var_check INTEGER;
        BEGIN
            SELECT areeFasceOrarie.idArea INTO var_check
            FROM aree
            INNER JOIN areeFasceOrarie ON aree.idArea = areefasceorarie.idArea
            WHERE areefasceorarie.idArea = idRiga;
            
            IF var_check IS NOT NULL THEN
                RAISE exc_assocArea;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                var_check := NULL;
        END;
        
        FOR i IN 1..12 
        LOOP
            INSERT INTO areefasceorarie(idArea, idFasciaOraria)
            VALUES (idRiga, i);
        END LOOP;
        
        modGUI.esitoOperazione('OK', 'Inserimento completato con successo');
        
        EXCEPTION
            WHEN exc_errCosto THEN
                modGUI.esitoOperazione('KO', 'Costi non validi');
            WHEN exc_assocArea THEN
                modGUI.esitoOperazione('KO', 'Associazione già presente');
            WHEN OTHERS THEN
                modGUI.esitoOperazione('KO', 'Formato degli input non validi');
        modGUI.chiudiDiv;
        
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        modGUI.chiudiPagina;
    
    END inserimentoAreaFasce;
    
    PROCEDURE visualizzaDettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_giorni VARCHAR2) IS
        CURSOR cur_dettagli IS
            SELECT nome, cognome, (CAST(ingressiorari.orauscita AS DATE) - CAST(ingressiorari.oraentrata AS DATE)) *24 as giorniorari,
    (CAST(ingressiabbonamenti.orauscita AS DATE) - CAST(ingressiabbonamenti.oraentrata AS DATE)) *24 as giorniabb,
            autorimesse.indirizzo
            FROM clienti
            INNER JOIN persone ON clienti.idpersona = persone.idpersona
            LEFT JOIN effettuaIngressiAbbonamenti ON clienti.idcliente = effettuaingressiabbonamenti.idcliente
            INNER JOIN ingressiabbonamenti ON effettuaingressiabbonamenti.idingressoabbonamento = ingressiabbonamenti.idingressoabbonamento
            LEFT JOIN effettuaingressiorari ON clienti.idcliente = effettuaingressiorari.idingressoorario
            INNER JOIN ingressiorari ON effettuaingressiorari.idingressoorario = ingressiorari.idingressoorario
            INNER JOIN box ON ingressiorari.idbox = box.idbox
            INNER JOIN aree ON box.idarea = aree.idarea
            INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
            WHERE ingressiOrari.idIngressoOrario NOT IN (SELECT idIngressoOrario
                                                            FROM ingressiOrari
                                                            WHERE ((CAST(orauscita AS DATE) - CAST(oraentrata AS DATE)) *24) <= var_giorni)
            AND ingressiAbbonamenti.idIngressoAbbonamento NOT IN (SELECT idIngressoAbbonamento
                                                                    FROM ingressiabbonamenti
                                                                    WHERE ((CAST(orauscita AS DATE) - CAST(oraentrata AS DATE)) *24) <= var_giorni);
    BEGIN
        modGUI.apriPagina('HoC | Visualizza dettagli ingressi X', id_Sessione, nome, ruolo);
        modGUI.apriDiv;
        modGUI.apriIntestazione(3);
            modGUI.inserisciTesto('VISUALIZZA DETTAGLI INGRESSI X');
        modGUI.chiudiIntestazione(3);
        
        modGUI.apriTabella;
        modGUI.apriRigaTabella;
            modGUI.intestazioneTabella('CLIENTE');
            modGUI.intestazioneTabella('AUTORIMESSE');
            modGUI.intestazioneTabella('GIORNI DI PERMANENZA (ABB)');
            modGUI.intestazioneTabella('GIORNI DI PERMANENZA (NABB)');
        modGUI.chiudiRigaTabella;
        
        FOR row_dettagli IN cur_dettagli
        LOOP
            modGUI.apriRigaTabella;
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_dettagli.nome || ' ' || row_dettagli.cognome);
                modGUI.chiudiElementoTabella;
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_dettagli.indirizzo);
                modGUI.chiudiElementoTabella;
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_dettagli.giorniabb);
                modGUI.chiudiElementoTabella;
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_dettagli.giorniorari);
                modGUI.chiudiElementoTabella;
            modGUI.chiudiRigaTabella;
        END LOOP;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END visualizzaDettagliXGiorni;
    
    PROCEDURE visualizzaPermanenza(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2, var_anno VARCHAR2,
        var_tipo VARCHAR2) IS
    
        --contiene le fasce orarie ordinate per giorno e ora di inizio
        CURSOR cur_fasce IS
        SELECT fasceorarie.idfasciaoraria, fasceorarie.nome
            FROM fasceorarie
            ORDER BY CASE
                WHEN giorno = 'LUN' THEN 1
                WHEN giorno = 'MAR' THEN 2
                WHEN giorno = 'MER' THEN 3
                WHEN giorno = 'GIO' THEN 4
                WHEN giorno = 'VEN' THEN 5
                WHEN giorno = 'SAB' THEN 6
                WHEN giorno = 'DOM' THEN 7
              END, orainizio ASC;
        
        var_contaAutorimessa INTEGER;
        
        var_giorni INTEGER;
        var_ore INTEGER;
        var_minuti INTEGER;
        
        var_calcoloSecondi array_int := array_int();
    BEGIN
        modGUI.apriPagina('HoC | Statistiche permanenza', id_Sessione, nome, ruolo);
        modGUI.aCapo;
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('TEMPO MEDIO PERMANENZA NON ABBONATI');
        modGUI.chiudiIntestazione(2);
        
        IF NOT checkAutorimessa(var_autorimessa) THEN
            RAISE exc_noAutorimessa;
        END IF;
        
        modGUI.apriIntestazione(4);
            modGUI.inserisciTesto('AUTORIMESSA DI RIFERIMENTO: ');
            modGUI.collegamento(var_autorimessa, 'link');
                modGUI.aCapo;
            modGUI.inserisciTesto('ANNO DI RIFERIMENTO: ');
            modGUI.collegamento(var_anno, 
                                'ale.visualizzaCronologia?id_Sessione=' || id_sessione || '&nome=' || nome || '&ruolo=' || ruolo ||
                                '&var_autorimessa=' || var_autorimessa || '&var_cliente=' || '&var_targa=' || '&var_dataInizio=' ||
                                var_anno || '-1-1' || '&var_dataFine=' || var_anno || '-12-1');
        modGUI.chiudiIntestazione(4);
    
        modGUI.apriDiv;
            
        modGUI.apriTabella;
    
        IF var_tipo = 0 THEN
            var_calcoloSecondi := calcoloTempoMese(var_autorimessa, var_anno);
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('MESE');
                modGUI.intestazioneTabella('GIORNI');
                modGUI.intestazioneTabella('ORE');
                modGUI.intestazioneTabella('MINUTI');
                modGUI.intestazioneTabella('SECONDI');
            modGUI.chiudiRigaTabella;
            
            FOR i IN 1..12
            LOOP
                DECLARE
                    var_show BOOLEAN := var_calcoloSecondi(i) != 0;
                BEGIN
                var_minuti := TRUNC(var_calcoloSecondi(i) / 60);
                var_calcoloSecondi(i) := var_calcoloSecondi(i) - (var_minuti * 60);
        
                var_ore := TRUNC(var_minuti / 60);
                var_minuti := var_minuti - (var_ore * 60);
        
                var_giorni := TRUNC(var_ore / 24);
                var_ore := var_ore - (var_giorni * 24);
            
                modGui.apriRigaTabella;
                    modGUI.apriElementoTabella;
                        IF NOT var_show THEN
                            modGUI.ElementoTabella(TO_CHAR(TO_DATE(i, 'MM'), 'Month', 'NLS_DATE_LANGUAGE = italian'));
                        ELSE
                            -- se ci sono stati ingressi per quel mese inserisco un collegamento per farli visualizzare
                            modGUI.collegamento(TO_CHAR(TO_DATE(i, 'MM'), 'Month', 'NLS_DATE_LANGUAGE = italian'),
                                'ale.visualizzaCronologia?id_Sessione=' || id_sessione || '&nome=' || nome || '&ruolo=' || ruolo ||
                                '&var_autorimessa=' || var_autorimessa || '&var_cliente=' || '&var_targa=' || '&var_dataInizio=' ||
                                var_anno || '-' || i || '-1' || '&var_dataFine=' ||
                                TO_CHAR(LAST_DAY(TO_DATE('1-' || i || '-' || var_anno, 'DD-MM-RR')), 'YYYY-MM-DD'));
                        END IF;
                    modGUI.chiudiElementoTabella;
        
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_giorni);
                    modGUI.chiudiElementoTabella;
                    dbms_output.put_line('giorni ' || var_giorni);
        
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_ore);
                    modGUI.chiudiElementoTabella;
                    dbms_output.put_line('ore ' || var_ore);
                    
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_minuti);
                    modGUI.chiudiElementoTabella;
                
                    dbms_output.put_line('minuti ' || var_minuti);
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_calcoloSecondi(i));
                    modGUI.chiudiElementoTabella;
                    dbms_output.put_line('secondi ' || var_calcoloSecondi(i));
                    
                modGUI.chiudiRigaTabella;
            END;
            END LOOP;
        ELSIF var_tipo = 1 THEN
            var_calcoloSecondi := calcoloTempoFascia(var_autorimessa, var_anno);
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('FASCIA');
                modGUI.intestazioneTabella('DETTAGLIO FASCIA');
                modGUI.intestazioneTabella('GIORNI');
                modGUI.intestazioneTabella('ORE');
                modGUI.intestazioneTabella('MINUTI');
                modGUI.intestazioneTabella('SECONDI');
            modGUI.chiudiRigaTabella;
            
            FOR row_fasce IN cur_fasce
            LOOP
                var_minuti := TRUNC(var_calcoloSecondi(row_fasce.idfasciaoraria) / 60);
                var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria) - (var_minuti * 60);
        
                var_ore := TRUNC(var_minuti / 60);
                var_minuti := var_minuti - (var_ore * 60);
        
                var_giorni := TRUNC(var_ore / 24);
                var_ore := var_ore - (var_giorni * 24);
            
                modGui.apriRigaTabella;
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(row_fasce.nome);
                    modGUI.chiudiElementoTabella;
                    
                    modGUI.apriElementoTabella;
                        modGUI.inserisciLente('ale.dettaglioFascia', id_Sessione, nome, ruolo, row_fasce.idFasciaoraria);
                    modGUI.chiudiElementoTabella;
                    
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_giorni);
                    modGUI.chiudiElementoTabella;
                    
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_ore);
                    modGUI.chiudiElementoTabella;
                    
                    modGUI.ApriElementoTabella;
                        modGUI.ElementoTabella(var_minuti);
                    modGUI.ChiudiElementoTabella;
                    
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_calcoloSecondi(row_fasce.idfasciaoraria));
                    modGUI.chiudiElementoTabella;
                modGUI.chiudiRigaTabella;
            END LOOP;
         ELSIF var_tipo = 2 THEN
            DECLARE
                var_secondi INTEGER;
                var_minuti INTEGER;
                var_ore INTEGER;
                var_giorni INTEGER;
                CURSOR cur_media IS
                    SELECT clienti.idCliente, nome, cognome, codicefiscale,
                        AVG(((CASE WHEN EXTRACT(YEAR FROM orauscita) = var_anno
                                    THEN CAST(orauscita AS DATE)
                                    ELSE TO_DATE('31-DIC-' || var_anno || ' 23:59:59', 'DD-MON-RR HH24:MI:SS', 'NLS_DATE_LANGUAGE = italian') END)
                            -
                            (CASE WHEN EXTRACT(YEAR FROM oraEntrata) = var_anno
                                    THEN CAST(oraEntrata AS DATE)
                                    ELSE TO_DATE('1-GEN-' || var_anno || ' 0:0:0', 'DD-MON-RR HH24:MI:SS','NLS_DATE_LANGUAGE = italian') END)) * 86400) AS media
                    FROM clienti 
                    INNER JOIN persone ON clienti.idPersona = persone.idpersona
                    INNER JOIN effettuaingressiorari ON clienti.idcliente = effettuaingressiorari.idcliente
                    INNER JOIN ingressiorari ON effettuaingressiorari.idingressoorario = ingressiorari.idingressoorario
                    INNER JOIN box ON ingressiorari.idBox = box.idBox
                    INNER JOIN aree ON box.idArea = aree.idArea
                    INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
                    WHERE (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT (YEAR FROM orauscita) = var_anno) AND autorimesse.indirizzo = var_autorimessa
                    GROUP BY clienti.idCliente, codiceFiscale, nome, cognome
                    ORDER BY nome, cognome;
            BEGIN
            var_calcoloSecondi := calcoloTempoFascia(var_autorimessa, var_anno);
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('CLIENTE');
                modGUI.intestazioneTabella('DETTAGLI CLIENTE');
                modGUI.intestazioneTabella('GIORNI');
                modGUI.intestazioneTabella('ORE');
                modGUI.intestazioneTabella('MINUTI');
                modGUI.intestazioneTabella('SECONDI');
            modGUI.chiudiRigaTabella;
            
            FOR row_media IN cur_media
            LOOP
                var_secondi := row_media.media;
            
                var_minuti := TRUNC(var_secondi / 60);
                var_secondi := var_secondi - (var_minuti * 60);
        
                var_ore := TRUNC(var_minuti / 60);
                var_minuti := var_minuti - (var_ore * 60);
        
                var_giorni := TRUNC(var_ore / 24);
                var_ore := var_ore - (var_giorni * 24);
            
                modGUI.apriRigaTabella;
                    modGUI.apriElementoTabella;
                        modGUI.collegamento(row_media.nome || ' ' || row_media.cognome, 
                            'ale.visualizzaCronologia?id_Sessione=' || id_sessione || '&nome=' || nome || '&ruolo=' || ruolo ||
                                '&var_autorimessa=' || var_autorimessa || '&var_cliente=' || row_media.codicefiscale || '&var_targa=' || '&var_dataInizio=' ||
                                var_anno || '-1-1' || '&var_dataFine=' || '2019-12-1');
                    modGUI.chiudiElementoTabella;
                    modGUI.apriElementoTabella;
                        modGUI.inserisciLente('link', id_Sessione, nome, ruolo, row_media.idCliente);
                    modGUI.chiudiElementoTabella;
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_giorni);
                    modGUI.chiudiElementoTabella;
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_ore);
                    modGUI.chiudiElementoTabella;
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_minuti);
                    modGUI.chiudiElementoTabella;
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(var_secondi);
                    modGUI.chiudiElementoTabella;
                modGUI.chiudiRigaTabella;
            END LOOP;
            
            END;
        END IF;

        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
        
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        EXCEPTION 
            WHEN exc_noAutorimessa THEN
                modGUI.esitoOperazione('KO', 'L''autorimessa specificata non esiste');
            WHEN OTHERS THEN
                modGUI.esitoOperazione('KO', 'Formati degli input non validi');
        
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END visualizzaPermanenza;
    
    PROCEDURE percentualePrenotazioni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
        -- contiene gli anni in cui si sono avuti ingressi
        CURSOR cur_anni IS
            SELECT DISTINCT EXTRACT(YEAR FROM oraentrata) AS anno
            FROM ingressiorari
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
                UNION 
            SELECT DISTINCT EXTRACT(YEAR FROM orauscita) AS anno
            FROM ingressiOrari
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
            ORDER BY anno;
            
        row_anni cur_anni%ROWTYPE;
    BEGIN
        modGUI.apriPagina('HoC | Percentuale prenotazioni', id_Sessione, nome, ruolo);
        modGUI.aCapo;
        modGUI.apriDiv;
       
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('PERCENTUALE PRENOTAZIONI');
        modGUI.chiudiIntestazione(2);
        
        modGUI.apriForm('ale.visualizzaPercentuale');
            
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        modGUI.apriSelect('var_anno', 'ANNO');
            FOR row_anni IN cur_anni
            LOOP
                modGUI.inserisciOpzioneSelect(row_anni.anno, row_anni.anno, false);
            END LOOP;
        modGUI.chiudiSelect;
        
        modGUI.inserisciTesto('PERCENTUALE PER:');
        modGUI.aCapo;
        modGUI.aCapo;
        modGUI.inserisciRadioButton('AUTORIMESSA', 'var_tipo', '0', true);
        modGUI.inserisciRadioButton('CLIENTE', 'var_tipo', '1', false);
        
        modGUI.inserisciBottoneReset;
        modGUI.inserisciBottoneForm('SUBMIT');
        modGUI.chiudiForm;
        
        modGUI.chiudiDiv;
        modGUI.aCapo;
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END percentualePrenotazioni;
    
    PROCEDURE visualizzaPercentuale(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_anno VARCHAR2, var_tipo VARCHAR2) IS
        prenotazione rec_prenot;
    BEGIN
        modGUI.apriPagina('HoC | Percentuale prenotazioni', id_Sessione, nome, ruolo);
        
        IF var_tipo != '0' AND var_tipo != '1' THEN
            RAISE exc_noTipo;
        END IF;
        
        IF var_tipo = 0 THEN
            DECLARE
                CURSOR cur_autorimesse IS
                    SELECT idautorimessa, indirizzo
                    FROM autorimesse
                    ORDER BY indirizzo ASC;
                    
                row_autorimesse cur_autorimesse%ROWTYPE;
            BEGIN
            
            modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('PERCENTUALE PER PARCHEGGI');
            modGUI.chiudiIntestazione(2);
            
            modGUI.apriDiv;
            modGUI.apriTabella;
                modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('AUTORIMESSA');
                modGUI.intestazioneTabella('DETTAGLI AUTORIMESSA');
                modGUI.intestazioneTabella('INGRESSI TOTALI');
                modGUI.intestazioneTabella('INGRESSI CON PRENOTAZIONE');
                modGUI.intestazioneTabella('INGRESSI SENZA PRENOTAZIONE');
                modGUI.intestazioneTabella('PERCENTUALE');
                modGUI.chiudiRigaTabella;
            
            FOR row_autorimesse IN cur_autorimesse
            LOOP
                prenotazione := calcoloInfoPrenotAutorim(row_autorimesse.idAutorimessa, var_anno);
                
                modGUI.apriRigaTabella;
                
                -- INDIRIZZO + DETTAGLI DELL'AUTORIMESSA --
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_autorimesse.indirizzo);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.inserisciLente('dettagliAutorimessa', id_Sessione, nome, ruolo, row_autorimesse.idAutorimessa);
                modGUI.chiudiElementoTabella;
                
                -- NUMERO DI INGRESSI TOTALI --
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(prenotazione.var_totale);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(prenotazione.var_numPrenotazione);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(prenotazione.var_numSenzaPrenotazione);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    IF prenotazione.var_percentuale IS NULL THEN
                        modGUI.elementoTabella('0%');
                    ELSE
                        modGUI.elementoTabella(prenotazione.var_percentuale || '%');
                    END IF;
                modGUI.chiudiElementoTabella;
                modGUI.chiudiRigaTabella;
            END LOOP;
            
            modGUI.chiudiTabella;
            END;
        ELSE 
            DECLARE
                CURSOR cur_persone IS
                    SELECT idCliente, nome, cognome
                    FROM persone
                    INNER JOIN clienti ON persone.idpersona = clienti.idpersona
                    ORDER BY cognome, nome ASC;
                    
                row_persone cur_persone%ROWTYPE;
            BEGIN
            
            modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('PERCENTUALE PER CLIENTI');
            modGUI.chiudiIntestazione(2);
            
            modGUI.apriDiv;
            modGUI.apriTabella;
                modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('GENERALITA''');
                modGUI.intestazioneTabella('INGRESSI TOTALI');
                modGUI.intestazioneTabella('INGRESSI CON PRENOTAZIONE');
                modGUI.intestazioneTabella('INGRESSI SENZA PRENOTAZIONE');
                modGUI.intestazioneTabella('PERCENTUALE');
                modGUI.chiudiRigaTabella;
            
            FOR row_persone IN cur_persone
            LOOP
                prenotazione := calcoloInfoPrenotCliente(row_persone.idcliente, var_anno);
                
                modGUI.apriRigaTabella;
                
                    -- GENERALITA' DEL CLIENTE --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(row_persone.cognome || ' ' || row_persone.nome);
                        modGUI.aCapo;
                        modGUI.inserisciLente('dettagliCliente', id_Sessione, nome, ruolo, row_persone.idCliente);
                    modGUI.chiudiElementoTabella;
                    
                    -- NUMERO DI INGRESSI TOTALI --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(prenotazione.var_totale);
                    modGUI.chiudiElementoTabella;
                    
                    -- NUMERO DI PRENOTAZIONI --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(prenotazione.var_numPrenotazione);
                    modGUI.chiudiElementoTabella;
                    
                    -- NUMERO DI INGRESSI SENZA PRENOTAZIONE --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(prenotazione.var_numSenzaPrenotazione);
                    modGUI.chiudiElementoTabella;
                    
                    -- PERCENTUALE DI PRENOTAZIONI RISPETTO AL TOTALE
                    modGUI.apriElementoTabella;
                        IF prenotazione.var_percentuale IS NULL THEN
                            modGUI.elementoTabella('0%');
                        ELSE
                            modGUI.elementoTabella(prenotazione.var_percentuale || '%');
                        END IF;
                    modGUI.chiudiElementoTabella;
            END LOOP;
            modGUI.chiudiTabella;
            END;
        END IF;
        
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        EXCEPTION 
            WHEN exc_noTipo THEN
                modGUI.esitoOperazione('KO', 'Il tipo selezionato non e'' riconosciuto');
            WHEN OTHERS THEN
                modGUI.esitoOperazione('KO', 'Formati degli input non validi');
        
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END visualizzaPercentuale;
    
    PROCEDURE cronologiaAccessi(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
        CURSOR cur_autorimesse IS
            SELECT idautorimessa, indirizzo
            FROM autorimesse;
            
        row_autorimesse cur_autorimesse%ROWTYPE;
    BEGIN
        modGUI.apriPagina('HoC | Cronologia Accessi', id_Sessione, nome, ruolo);
        
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.InserisciTesto('CRONOLOGIA ACCESSI');
        modGUI.chiudiIntestazione(2);
        
        modGUI.apriForm('ale.visualizzaCronologia');
        
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
        modGUI.inserisciOpzioneSelect('', '--Tutte le autorimesse--');
        FOR row_autorimesse IN cur_autorimesse
        LOOP
            modGUI.inserisciOpzioneSelect(row_autorimesse.indirizzo, row_autorimesse.indirizzo);
        END LOOP;
        modGUI.chiudiSelect;
        
        -- codice fiscale, campo non obbligatorio
        modGUI.inserisciTesto('CODICE FISCALE');
        modGUI.inserisciInput('var_cliente', 'Codice Fiscale', 'text', false);
        
        -- targa, campo non obbligatorio
        modGUI.inserisciTesto('TARGA');
        modGUI.inserisciInput('var_targa', 'Targa', 'text', false);
        
        -- data di inizio, campo obbligatorio
        modGUI.inserisciInput('var_dataInizio', 'DATA INIZIO', 'date', true);
        
        -- data di fine, campo obbligatorio
        modGUI.inserisciInput('var_dataFine', 'DATA FINE', 'date', true);
        
        modGUI.inserisciBottoneReset;
        modGUI.inserisciBottoneForm('SUBMIT');
        modGUI.chiudiForm;
        
        modGUI.chiudiDiv;
        
        modGUI.aCapo;
        
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END cronologiaAccessi;
    
    PROCEDURE visualizzaCronologia(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2 DEFAULT '',
        var_cliente VARCHAR2 DEFAULT '', var_targa VARCHAR2 DEFAULT '', var_dataInizio VARCHAR2, var_dataFine VARCHAR2) IS
        
        var_contaAutorimessa INTEGER;
        var_contaCliente INTEGER;
        var_contaTarga INTEGER;
        
        CURSOR cur_ingressi IS
            SELECT IngressiOrari.idIngressoOrario, entrataprevista, oraentrata, orauscita,
                    clienti.idCliente, CodiceFiscale,
                    targa, modello, veicoli.idVeicolo,
                    autorimesse.idAutorimessa, autorimesse.indirizzo,
                    aree.idArea,
                    idmulta
            FROM ingressiorari
            INNER JOIN box ON ingressiOrari.idBox = box.idBox
            INNER JOIN aree ON box.idArea = aree.idArea
            INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
            INNER JOIN effettuaingressiorari ON ingressiorari.idingressoorario = effettuaingressiorari.idingressoorario
            INNER JOIN clienti ON effettuaIngressiOrari.idCliente = clienti.idCliente
            INNER JOIN persone ON clienti.idPersona = persone.idPersona
            INNER JOIN veicoli ON effettuaingressiorari.idveicolo = veicoli.idveicolo
            WHERE autorimesse.indirizzo LIKE (CASE WHEN var_autorimessa IS NULL THEN '%'
                                                                ELSE var_autorimessa END) AND
                   codiceFiscale LIKE (CASE WHEN var_cliente IS NULL THEN '%'
                                                                        ELSE var_cliente END) AND
                    veicoli.targa LIKE (CASE WHEN var_targa IS NULL THEN '%'
                                            ELSE var_targa END) AND 
                oraEntrata <= TO_TIMESTAMP(TO_CHAR(TO_TIMESTAMP(var_dataFine, 'YYYY-MM-DD'), 'DD-MON-RR') || ' 23:59:59', 'DD-MON-RR HH24:MI:SS') AND
                oraUscita >= TO_TIMESTAMP(TO_CHAR(TO_TIMESTAMP(var_dataInizio, 'YYYY-MM-DD'), 'DD-MON-RR') || ' 0:0:0', 'DD-MON-RR HH24:MI:SS')
                
            ORDER BY autorimesse.idAutorimessa, clienti.idCliente, veicoli.idVeicolo, oraEntrata ASC;
            
        var_noRecord BOOLEAN := true;
    BEGIN
        modGUI.apriPagina('HoC | Cronologia Accessi', id_Sessione, nome, ruolo);
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('CRONOLOGIA ACCESSI');
        modGUI.chiudiIntestazione(2);
        
        IF var_dataInizio IS NULL OR var_dataFine IS NULL THEN
            RAISE exc_dataNulla;
        END IF;
        
        IF var_autorimessa IS NOT NULL AND NOT checkAutorimessa(var_autorimessa) THEN
            RAISE exc_noCliente;
        END IF;
        
        IF var_cliente IS NOT NULL AND NOT checkCliente(var_cliente) THEN
            RAISE exc_noCliente;
        END IF;
        
        IF var_targa IS NOT NULL AND NOT checkTarga(var_targa) THEN
            RAISE exc_noTarga;
        END IF;
        modGUI.apriDiv;        
        
        modGUI.apriIntestazione(3);
            modGUI.inserisciTesto('DATA DI INIZIO: ' || TO_CHAR(TO_DATE(var_dataInizio, 'YYYY-MM-DD'), 'DD-MON-YYYY', 'NLS_DATE_LANGUAGE = italian'));
            modGUI.aCapo;
            modGUI.inserisciTesto('DATA DI FINE: ' || TO_CHAR(TO_DATE(var_dataFine, 'YYYY-MM-DD'), 'DD-MON-YYYY', 'NLS_DATE_LANGUAGE = italian'));
            modGUI.aCapo;
            IF var_autorimessa IS NOT NULL THEN
                    modGUI.inserisciTesto('AUTORIMESSA: ');
                    modGUI.collegamento(var_autorimessa, 'link');
                    modGUI.aCapo;
            END IF;
            IF var_cliente IS NOT NULL THEN
                    modGUI.inserisciTesto('CLIENTE: ');
                    modGUI.collegamento(var_cliente, 'link');
                    modGUI.aCapo;
            END IF;
            IF var_targa IS NOT NULL THEN
                    modGUI.inserisciTesto('TARGA: ');
                    modGUI.collegamento(var_targa, 'link');
            END IF;
        modGUI.chiudiIntestazione(3);
          
        DECLARE 
            primo INTEGER;
            secondo INTEGER;
            terzo INTEGER;
        BEGIN
        primo := -1;
        secondo := -1;
        terzo := -1;
        FOR row_ingressi IN cur_ingressi
        LOOP
            var_noRecord := FALSE;
        
            IF primo != row_ingressi.idAutorimessa THEN
                IF primo != -1 THEN
                    modGUI.chiudiTabella;
                    modGUI.apriIntestazione(3);
                ELSIF primo = -1 AND secondo = -1 AND terzo = -1 THEN
                    modGUI.apriIntestazione(3);
                END IF;
              
                IF var_autorimessa IS NULL THEN
                    modGUI.inserisciTesto('AUTORIMESSA: ');
                    modGUI.collegamento(row_ingressi.indirizzo, 'link');
                    modGUI.aCapo;
                END IF;
                
                primo := row_ingressi.idAutorimessa;
                secondo := -1;
                terzo := -1;
            END IF;
            IF secondo != row_ingressi.idcliente THEN
                
                IF secondo != -1 THEN
                    modGUI.chiudiTabella;
                    modGUI.apriIntestazione(3);
                ELSIF primo = -1 AND secondo = -1 AND terzo = -1 THEN
                    modGUI.apriIntestazione(3);
                END IF;
                
                IF var_cliente IS NULL THEN
                    modGUI.inserisciTesto('CLIENTE: ');
                    modGUI.collegamento(row_ingressi.codiceFiscale, 'link');
                    modGUI.aCapo;
                END IF;
                
                secondo := row_ingressi.idCliente;
                terzo := -1;
            END IF;
            IF terzo != row_ingressi.idVeicolo THEN
                
                IF terzo != -1 THEN
                    modGUI.chiudiTabella;
                    modGUI.apriIntestazione(3);
                ELSIF primo = -1 AND secondo = -1 AND terzo = -1 THEN
                    modGUI.apriIntestazione(3);
                END IF;
                
                IF var_targa IS NULL THEN
                    modGUI.inserisciTesto('VEICOLO: ');
                    modGUI.collegamento(row_ingressi.targa, 'link');
                END IF;
                
                modGUI.chiudiIntestazione(3);
                modGUI.apriTabella;
                
                modGUI.apriRigaTabella;
                        modGUI.intestazioneTabella('ENTRATA PREVISTA');
                        modGUI.intestazioneTabella('ORA ENTRATA');
                        modGUI.intestazioneTabella('ORA USCITA');
                        modGUI.intestazioneTabella('DETTAGLI INGRESSO');
                        modGUI.intestazioneTabella('DETTAGLI AREA');
                        modGUI.intestazioneTabella('MULTA');
                modGUI.chiudiRigaTabella; 
                
                
                terzo := row_ingressi.idVeicolo;
            END IF;
            
            modGUI.apriRigaTabella;
                
            -- ENTRATA PREVISTA--
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(TO_CHAR(row_ingressi.entrataPrevista, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian'));
                modGUI.aCapo;
                modGUI.elementoTabella(TO_CHAR(row_ingressi.entrataPrevista, 'HH24:MI:SS', 'NLS_DATE_LANGUAGE = italian'));
            modGUI.chiudiElementoTabella;
                
            -- ENTRATA --
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(TO_CHAR(row_ingressi.oraEntrata, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian'));
                modGUI.aCapo;
                modGUI.elementoTabella(TO_CHAR(row_ingressi.oraEntrata, 'HH24:MI:SS', 'NLS_DATE_LANGUAGE = italian'));
            modGUI.chiudiElementoTabella;
                
            -- USCITA --
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(TO_CHAR(row_ingressi.orauscita, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian'));
                modGUI.aCapo;
                modGUI.elementoTabella(TO_CHAR(row_ingressi.orauscita, 'HH24:MI:SS', 'NLS_DATE_LANGUAGE = italian'));
            modGUI.chiudiElementoTabella;
                
            -- ALTRI DETTAGLI INGRESSO ORARIO --
            modGUI.apriElementoTabella;
                modGUI.inserisciLente('dettaglioBiglietto', id_Sessione, nome, ruolo, row_ingressi.idIngressoOrario);
            modGUI.chiudiElementoTabella;
                
            -- DETTAGLIO DELL'AREA UTILIZZATA --
            modGUI.apriElementoTabella;
                modGUI.inserisciLente('dettaglioArea', id_Sessione, nome, ruolo, row_ingressi.idarea);
            modGUI.chiudiElementoTabella;
                
            -- MULTE --
            modGUI.apriElementoTabella;
                IF row_ingressi.idMulta IS NULL THEN
                    -- Se ad un ingresso non è stata associata ancora una multa, espongo la procedura di inserimento
                    modGUI.inserisciPenna('inserisciMulta', id_Sessione, nome, ruolo, 'O' || row_ingressi.idingressoorario);
                ELSE
                    -- Se ad un ingresso è stata già associata una multa, espongo la procedura di visualizzazione
                    modGUI.inserisciLente('visualizzaMulta', id_Sessione, nome, ruolo, 'O' || row_ingressi.idmulta);
                END IF;
            modGUI.chiudiElementoTabella;
               
            modGUI.chiudiRigaTabella;
        END LOOP;
            modGUI.chiudiTabella;
        END;
        
        IF var_noRecord THEN
            modGUI.apriTabella;
                modGUI.apriRigaTabella;
                    modGUI.intestazioneTabella('ENTRATA PREVISTA');
                    modGUI.intestazioneTabella('ORA ENTRATA');
                    modGUI.intestazioneTabella('ORA USCITA');
                    modGUI.intestazioneTabella('DETTAGLI INGRESSO');
                    modGUI.intestazioneTabella('DETTAGLI AREA');
                    modGUI.intestazioneTabella('MULTA');
                modGUI.chiudiRigaTabella;
                
                modGUI.apriRigaTabella;
                FOR i IN 1 .. 6 
                LOOP
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(NULL);
                    modGUI.chiudiElementoTabella;
                END LOOP;
                modGUI.chiudiRigaTabella;
            modGUI.chiudiTabella;
        END IF;
        
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        EXCEPTION
            WHEN exc_dataNulla THEN
                modGUI.esitoOperazione('KO', 'Una delle date inserite è nulla');
            WHEN exc_noAutorimessa THEN
                modGUI.esitoOperazione('KO', 'L''autorimessa specificata non esiste');
            WHEN exc_noCliente THEN
                modGUI.esitoOperazione('KO', 'Il cliente specificato non esiste');
            WHEN exc_noTarga THEN
                modGUI.esitoOperazione('KO', 'Il veicolo specificato non esiste');
            WHEN OTHERS THEN
                modGUI.esitoOperazione('KO', 'Formato degli input non valido');
            
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
    END visualizzaCronologia;
    
    PROCEDURE visualizzaAreeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2) IS
        CURSOR cur_areeFasce IS
            SELECT indirizzo, areeFasceOrarie.idArea, areeFasceOrarie.idFasciaoraria, nome, costo
            FROM autorimesse
            INNER JOIN aree ON autorimesse.idAutorimessa = aree.idAutorimessa
            INNER JOIN areeFasceorarie ON aree.idArea = areefasceorarie.idArea
            INNER JOIN fasceorarie ON areeFasceOrarie.idFasciaOraria = fasceorarie.idfasciaoraria
            WHERE indirizzo LIKE (CASE WHEN var_autorimessa IS NULL THEN '%'
                                    ELSE var_autorimessa END)
            ORDER BY areeFasceOrarie.idArea, CASE
                            WHEN giorno = 'LUN' THEN 1
                            WHEN giorno = 'MAR' THEN 2
                            WHEN giorno = 'MER' THEN 3
                            WHEN giorno = 'GIO' THEN 4
                            WHEN giorno = 'VEN' THEN 5
                            WHEN giorno = 'SAB' THEN 6
                            WHEN giorno = 'DOM' THEN 7
                          END, oraInizio ASC;
                          
        CURSOR cur_aree IS
            SELECT indirizzo, idArea
            FROM aree
            INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
            WHERE aree.idArea NOT IN (  SELECT idArea
                                        FROM areeFasceOrarie);
                                    
        row_areeFasce cur_areeFasce%ROWTYPE;
    BEGIN
        modGUI.apriPagina('HoC | Aree x Fasce', id_Sessione, nome, ruolo);
        
        modGUI.apriDiv;
        
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('AREE X FASCE');
        modGUI.chiudiIntestazione(2);
        
        IF var_autorimessa IS NOT NULL AND NOT checkAutorimessa(var_autorimessa) THEN
            RAISE exc_noAutorimessa;
        END IF;
        
        IF var_autorimessa IS NOT NULL THEN
            modGUI.apriIntestazione(3);
                modGUI.inserisciTesto('AUTORIMESSA: ');
                modGUI.collegamento(var_autorimessa, 'link');
            modGUI.chiudiIntestazione(3);
        END IF;
        
        DECLARE
            primo INTEGER;
        BEGIN
            primo := -1;
            
            FOR row_areeFasce IN cur_areeFasce
            LOOP
                IF primo != row_areeFasce.idArea THEN
                    primo := row_areeFasce.idArea;
                    
                    IF primo != -1 THEN
                        modGUI.chiudiTabella;
                    END IF;
                    
                    IF var_autorimessa IS NULL THEN
                        modGUI.apriIntestazione(3);
                            modGUI.inserisciTesto('PARCHEGGIO: ');
                            modGUI.collegamento(row_areefasce.indirizzo, 'link');
                            modGUI.aCapo;
                            modGUI.inserisciTesto('AREA: ');
                            modGUI.collegamento(row_areefasce.idArea, 'link');
                        modGUI.chiudiIntestazione(3);
                    ELSE
                        modGUI.apriIntestazione(3);
                            modGUI.inserisciTesto('AREA: ');
                            modGUI.collegamento(row_areefasce.idArea, 'link');
                        modGUI.chiudiIntestazione(3);
                    END IF;
                    
                    modGUI.apriTabella;
                    modGUI.apriRigaTabella;
                        modGUI.intestazioneTabella('FASCIA');
                        modGUI.intestazioneTabella('DETTAGLI FASCIA');
                        modGUI.intestazioneTabella('COSTO');
                        modGUI.intestazioneTabella('MODIFICA COSTO');
                    modGUI.chiudiRigaTabella;
                END IF;
                modGUI.apriRigaTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_areeFasce.nome);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.inserisciLente('ale.dettagliofascia', id_Sessione, nome, ruolo, row_areeFasce.idFasciaoraria);
                modGUI.chiudiElementoTabella;
                    
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(TO_CHAR(row_areeFasce.costo) || ' €');
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.inserisciPenna('link', id_Sessione, nome, ruolo, 1);
                modGUI.chiudiElementoTabella;
                    
                modGUI.chiudiRigaTabella;
            END LOOP;
            
        END;
        modGUI.chiudiTabella;
        
        modGUI.apriIntestazione(3);
            modGUI.inserisciTesto('Aree che non sono state ancora associate alle fasce orarie possibili');
        modGUI.chiudiIntestazione(3);
            
        modGUI.apriTabella;
        
        modGUI.apriRigaTabella;
            modGUI.intestazioneTabella('ID AREA');
            modGUI.intestazioneTabella('DETTAGLI AREA');
            modGUI.intestazioneTabella('ASSOCIA FASCE');
            modGUI.intestazioneTabella('PARCHEGGIO');
            modGUI.intestazioneTabella('DETTAGLI PARCHEGGIO');
        modGUI.chiudiRigaTabella;
        FOR row_aree IN cur_aree 
        LOOP
            modGUI.apriRigaTabella;
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_aree.idArea);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.inserisciLente('link', id_Sessione, nome, ruolo, 1);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.inserisciPenna('link', id_Sessione, nome, ruolo, 1);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(row_aree.indirizzo);
                modGUI.chiudiElementoTabella;
                
                modGUI.apriElementoTabella;
                    modGUI.inserisciLente('link', id_Sessione, nome, ruolo, 1);
                modGUI.chiudiElementoTabella;
                
            modGUI.chiudiRigaTabella;
        END LOOP;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
        
        modGUI.apriDiv(true);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        EXCEPTION 
            WHEN exc_noAutorimessa THEN
                modGUI.esitoOperazione('KO', 'L''autorimessa specificata non esiste');
            WHEN OTHERS THEN    
                modGUI.esitoOperazione('KO', 'Il formato degli input non è valido');
        
            modGUI.chiudiDiv;
            modGUI.chiudiPagina;
    END visualizzaAreeFasce;
    
    PROCEDURE dettaglioFascia(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2) IS
        var_nome VARCHAR2(45);
        var_oraInizio TIMESTAMP;
        var_oraFine TIMESTAMP;
        var_giorno CHAR(3);
    BEGIN
        modGUI.apriPagina('HoC | Dettaglio fascia', id_Sessione, nome, ruolo);
        modGUI.apriDiv;
        modGUI.apriIntestazione(2);
            modGUI.inserisciTesto('DETTAGLIO FASCIA');
        modGUI.chiudiIntestazione(2);
        
        SELECT nome, orainizio, orafine, giorno INTO var_nome, var_oraInizio, var_oraFine, var_giorno
        FROM fasceorarie 
        WHERE idFasciaoraria = idRiga;
        
        modGUI.apriTabella;
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('NOME');
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(var_nome);
                modGUI.chiudiElementoTabella;
            modGUI.chiudiRigaTabella;
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('ORA INIZIO');
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(TO_CHAR(var_oraInizio, 'HH24:MI:SS'));
                modGUI.chiudiElementoTabella;
            modGUI.chiudiRigaTabella;
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('ORA FINE');
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(TO_CHAR(var_oraFine, 'HH24:MI:SS'));
                modGUI.chiudiElementoTabella;
            modGUI.chiudiRigaTabella;
            
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('GIORNO');
                modGUI.apriElementoTabella;
                    modGUI.elementoTabella(var_giorno);
                modGUI.chiudiElementoTabella;
            modGUI.chiudiRigaTabella;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
        
        modGUI.apriDiv(TRUE);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'link');
        modGUI.chiudiDiv;
        
        modGUI.chiudiPagina;
    END dettaglioFascia;
    
END ALE;

/
