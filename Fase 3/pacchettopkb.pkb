CREATE OR REPLACE PACKAGE BODY ALESSANDRO AS

TYPE array_int IS VARRAY(12) OF INTEGER;
  TYPE nested_fasce IS TABLE OF INTEGER;
  TYPE rec_prenot IS RECORD (
      var_conPrenotazione INTEGER,
      var_senzaPrenotazione INTEGER,
      var_totale INTEGER,
      var_percentuale NUMBER(5,2)
  );

/*
    Funzione che verifica l'esistenza o meno di un'autorimessa
    @param: var_autorimessa = indirizzo dell'autorimessa
    @return: true se l'autorimessa esiste, false altrimenti
*/
FUNCTION checkAutorimessa(var_autorimessa VARCHAR2) RETURN BOOLEAN IS
    var_contaAutorimessa INTEGER;
BEGIN
    SELECT COUNT(idAutorimessa) INTO var_contaAutorimessa
    FROM Autorimesse
    WHERE indirizzo = var_autorimessa;

    RETURN var_contaAutorimessa = 1;
END checkAutorimessa;

/*
    Funzione che verifica l'esistenza o meno di un cliente
    @param: var_cliente = codice fiscale del cliente
    @return: true se il cliente esiste, false altrimenti
*/
FUNCTION checkCliente(var_cliente VARCHAR2) RETURN BOOLEAN IS
    var_contaCliente INTEGER;
BEGIN
    SELECT COUNT(idCliente) INTO var_contaCliente
    FROM Clienti
    INNER JOIN Persone ON clienti.idPersona = persone.idPersona
    WHERE codiceFiscale = var_cliente;

    RETURN var_contaCliente = 1;
END checkCliente;

/*
    Funzione che verifica l'esistenza e la proprieta' di un veicolo
    @param: var_targa = targa del veicolo
    @return: true se il veicolo esiste, false altrimenti
*/
FUNCTION checkTarga(var_targa VARCHAR2, var_cliente VARCHAR2) RETURN BOOLEAN IS
    var_contaTarga INTEGER;
BEGIN
    IF var_cliente IS NOT NULL THEN
        SELECT COUNT(veicoli.idVeicolo) INTO var_contaTarga
        FROM Veicoli
        INNER JOIN veicoliClienti ON veicoli.idveicolo = veicoliclienti.idVeicolo
        INNER JOIN clienti ON veicoliclienti.idcliente = clienti.idcliente
        INNER JOIN persone ON clienti.idpersona = persone.idpersona
        WHERE targa = var_targa AND codicefiscale = var_cliente;
    ELSE 
        SELECT COUNT(veicoli.idVeicolo) INTO var_contaTarga
        FROM Veicoli
        WHERE targa = var_targa;
    END IF;
    RETURN var_contaTarga = 1;
END checkTarga;

/*
    Converte il timestamp ricevuto in input in secondi, considerando l'ora, i minuti e i secondi.
    @param: var_ora = il timestamp da convertire e di cui mi interessa solamente l'ora, i minuti e i secondi
    @return: un intero che rappresenta la conversione, in secondi, del timestamp
*/
FUNCTION convertiOraInSecondi(var_ora TIMESTAMP) RETURN INTEGER IS
BEGIN
    RETURN (EXTRACT(HOUR FROM var_ora) * 3600) +
            (EXTRACT(MINUTE FROM var_ora) * 60) +
            EXTRACT(SECOND FROM var_ora);
END convertiOraInSecondi;

/*
    Calcola la percentuale di ingressi orari con prenotazione dal punto di vista del cliente
    @param: var_idCliente = id del cliente di cui mi interessano gli ingressi orari
    @param: var_anno = anno degli ingressi che mi interessano
*/
FUNCTION calcoloInfoPrenotCliente(var_idCliente VARCHAR2, var_anno VARCHAR2) RETURN rec_prenot IS
    -- record che andra' a contenere le informazioni di tutte le prenotazioni fatte dal cliente identificato da var_idcliente
    -- durante l'anno specificato da var_anno
    infoPrenotazioni rec_prenot;
BEGIN
    SELECT COUNT(ingressiorari.entrataprevista), COUNT(*), AVG(COUNT(ingressiorari.entrataprevista)) * 100
        INTO infoPrenotazioni.var_conPrenotazione, infoPrenotazioni.var_totale, infoPrenotazioni.var_percentuale
    FROM ingressiorari
    INNER JOIN effettuaingressiorari ON ingressiorari.idingressoorario = effettuaingressiorari.idingressoorario
    WHERE
        -- considero solo gli ingressi fatti dal cliente identificato da var_idCliente
        effettuaingressiorari.idcliente = var_idcliente AND
        -- considero solo gli ingressi che hanno l'anno di entrata o uscita uguale a quello specificato in var_anno
        -- vengono considerati anche gli ingressiorari che sono ancora in corso, cioÃ¨ con l'ora di uscita pari a NULL
        (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT(YEAR FROM orauscita) = var_anno) AND
        ingressiorari.cancellato = 'F'
    GROUP BY ingressiorari.entrataprevista;

    -- calcolo gli ingressi senza prenotazione
    infoPrenotazioni.var_senzaPrenotazione := infoPrenotazioni.var_totale - infoPrenotazioni.var_conPrenotazione;

    RETURN infoPrenotazioni;
END calcoloInfoPrenotCliente;

/*
    Calcola le informazioni sugli ingressi orari con prenotazione, dal punto di vista dell'autorimessa, che sono stati
    fatti in un dato anno
    @param: var_idAutorimessa = identificativo dell'autorimessa di cui mi interessano gli ingressi orari
    @param: var_anno = anno degli ingressi che mi interessano
*/
FUNCTION calcoloInfoPrenotAutorim(var_idAutorimessa VARCHAR2, var_anno VARCHAR2) RETURN rec_prenot IS
    -- record che andra' a contenere le informazioni di tutte le prenotazioni fatte dal cliente identificato da var_idcliente
    -- durante l'anno specificato da var_anno
    infoPrenotazioni rec_prenot;
BEGIN
    SELECT COUNT(entrataPrevista), COUNT(*), AVG(COUNT(entrataprevista)) * 100
        INTO infoPrenotazioni.var_conPrenotazione, infoPrenotazioni.var_totale, infoPrenotazioni.var_percentuale
    FROM ingressiOrari
    INNER JOIN box ON ingressiOrari.idBox = box.idBox
    INNER JOIN aree ON box.idArea = aree.idArea
    INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
    WHERE
        -- considero solamente gli ingressi che vengono fatti nell'autorimessa identificata da var_idAutorimessa
        autorimesse.idAutorimessa = var_idAutorimessa AND
        -- considero solo gli ingressi che hanno l'anno di entrata o uscita uguale a quello specificato in var_anno
        -- vengono considerati anche gli ingressiorari che sono ancora in corso, cioÃ¨ con l'ora di uscita pari a NULL
        (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT(YEAR FROM orauscita) = var_anno) AND
        ingressiorari.cancellato = 'F'
    GROUP BY ingressiOrari.entrataPrevista;

    -- calcolo gli ingressi senza prenotazione
    infoPrenotazioni.var_senzaPrenotazione := infoPrenotazioni.var_totale - infoPrenotazioni.var_conPrenotazione;

    RETURN infoPrenotazioni;
END calcoloInfoPrenotAutorim;

/*
    Calcola il tempo medio di permanenza degli ingressi orari, dal punto di vista dei mesi, che sono stati fatti in una
    determinata autorimessa e in un periodo di tempo che include l'anno passato come input

    @param(var_autorimessa): indirizzo dell'autorimessa di cui mi interessano gli ingressi orari
    @param(var_anno): anno di cui mi interessano gli ingressi orari
    @return: array di 12 posizioni contentente la media, in secondi, per ogni mese dell'anno specificato da var_anno
*/
FUNCTION calcoloTempoMese(var_autorimessa VARCHAR2, var_anno INTEGER) RETURN array_int IS
    CURSOR cur_ingressi IS
        SELECT oraentrata, orauscita
        FROM ingressiorari
        INNER JOIN box ON ingressiorari.idbox = box.idbox
        INNER JOIN aree ON box.idarea = aree.idarea
        INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
        WHERE
            orauscita IS NOT NULL AND
            -- considero solamente gli ingressi effettuati nell'autorimessa di indirizzo specificato da var_autorimessa
            autorimesse.indirizzo = var_autorimessa AND
            -- considero solo gli ingressi che hanno l'anno di entrata o uscita uguale a quello specificato in var_anno
            -- vengono considerati sia ingressi orari con prenotazione che senza
            (var_anno = EXTRACT(YEAR FROM oraentrata) OR var_anno = EXTRACT(YEAR FROM orauscita)) AND
            ingressiorari.cancellato = 'F';

    -- array che conterra' la media per ogni mese in secondi
    var_calcoloSecondi array_int := array_int();
    -- array che conterra' il numero di ingressi per quel mese, nel caso di ingressi a cavallo tra due o piu' mesi si considera
    -- un ingresso per ogni mese "attraversato"
    var_contatoriIngressi array_int := array_int();

    -- conterra' l'anno in cui e' stata registrata l'ora di entrata
    var_annoEntrata INTEGER;
    -- conterra' l'anno in cui e' stata registrata l'ora di uscita
    var_annoUscita INTEGER;

    -- conterra' il mese in cui e' stata registrata l'ora di entrata
    var_meseEntrata INTEGER;
    -- conterra' il mese in cui e' stata registrata l'ora di uscita
    var_meseUscita INTEGER;

    -- Conterra' l'ultimo giorno del mese X nel caso in cui l'entrata e uscita avvengono in mesi diversi
    --      OPPURE
    -- Conterra' l'ultimo giorno del mese di Dicembre (caso limite entrata e uscita a cavallo tra due anni e interessa
    --  il tempo medio dell'anno di entrata
    -- In ENTRAMBI i casi la componente indicante l'ora sara'ï¿½ settata a 23:59:59
    var_ultimoGiorno DATE;
    -- Conterra' il primo giorno del mese Y nel caso in cui l'entrata e uscita avvengono in mesi diversi
    --      OPPURE
    -- Conterra' il primo giorno del mese di Gennaio (caso limite entrata e uscita a cavallo tra due anni e interessa
    --  il tempo medio dell'anno di uscita
    -- In ENTRAMBI i casi la componente indicante l'ora sara'ï¿½ settata a 0:0:0
    var_primoGiorno DATE;
BEGIN
    FOR i IN 1..12
    LOOP
        -- inizializzo l'array che conterra' la media
        var_calcoloSecondi.extend();
        var_calcoloSecondi(i) := 0;

        -- inizializzo l'array di contatori degli ingressi
        var_contatoriIngressi.extend();
        var_contatoriIngressi(i) := 0;
    END LOOP;

    FOR row_ingressi IN cur_ingressi
    LOOP
        -- estraggo l'anno dall'ora di entrata
        var_annoEntrata := EXTRACT(YEAR FROM row_ingressi.oraEntrata);
        -- estraggo l'anno dall'ora di uscita
        var_annoUscita := EXTRACT(YEAR FROM row_ingressi.oraUscita);

        IF var_annoEntrata = var_annoUscita THEN
            -- caso in cui l'ingresso e l'uscita avvengono nello stesso anno

            -- estraggo il mese dall'ora di entrata
            var_meseEntrata := EXTRACT(MONTH FROM row_ingressi.oraEntrata);
            -- estraggo il mese dall'ora di uscita
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

                        -- aggiungo una parte di secondi a quel mese
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            ((var_ultimoGiorno - CAST(row_ingressi.oraentrata AS DATE)) * 86400);
                    ELSIF i = var_meseUscita THEN
                        -- sono nel mese in cui il cliente esce

                        -- aggiungo una parte di secondi a quel mese
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            ((CAST(row_ingressi.orauscita AS DATE) - var_primoGiorno) * 86400);
                    ELSE
                        -- tutti i mesi nel mezzo

                        -- aggiungo TUTTI i secondi del mese
                        var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                            (CAST(TO_CHAR(LAST_DAY(TO_DATE(i, 'MM')),'DD') AS INT) * 86400);
                    END IF;

                    -- +1 al contatore di quell'ingresso
                    var_contatoriIngressi(i) := var_contatoriIngressi(i) + 1;
                END LOOP;
            ELSE
                -- caso in cui l'ingresso e l'uscita sono nello stesso mese

                -- aggiungo TUTTI i secondi dell'ingresso a quel mese.
                var_calcoloSecondi(var_meseEntrata) := var_calcoloSecondi(var_meseEntrata) +
                    ((CAST(row_ingressi.orauscita AS DATE) - CAST(row_ingressi.oraentrata AS DATE)) * 86400);

                -- +1 al contatore per quel mese
                var_contatoriIngressi(var_meseEntrata) := var_contatoriIngressi(var_meseEntrata) + 1;
            END IF;
        ELSIF var_annoEntrata = var_anno THEN
            -- caso in cui l'entrata e l'uscita son in 2 anni diversi, "spezzo" l'ingresso considerando solo l'anno di entrata

            -- estraggo il mese di entrata
            var_meseEntrata := EXTRACT(MONTH FROM row_ingressi.oraEntrata);
            -- mi interessa il tempo medio riferito all'anno di entrata, quindi l'ingresso "termina" al mese di Dicembre
            var_meseUscita := 12;

            -- ottengo l'ultimo giorno del mese di ingresso
            var_ultimoGiorno := TO_DATE(TO_CHAR((LAST_DAY(CAST(row_ingressi.oraentrata AS DATE))),
                                                  'DD-MON-RR') || ' 23:59:59', 'DD-MON-RR HH24:MI:SS');

            FOR i IN var_meseEntrata .. var_meseUscita
            LOOP
                -- scorro tra i mesi di permanenza per calcolare i tempi

                IF i = var_meseEntrata THEN
                    -- sono nel mese in cui il cliente entra

                    -- aggiungo una parte di secondi al mese di entrata
                    var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                        ((var_ultimoGiorno - CAST(row_ingressi.oraentrata AS DATE)) * 86400);
                ELSE
                    -- tutti gli altri mesi

                    -- aggiungo tutti i secondi del mese
                    var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                        (CAST(TO_CHAR(LAST_DAY(TO_DATE(i, 'MM')),'DD') AS INT) * 86400);
                END IF;

                -- +1 al contatore degli ingressi i
                var_contatoriIngressi(i) := var_contatoriIngressi(i) + 1;
            END LOOP;
        ELSIF var_annoUscita = var_anno THEN
            -- caso in cui l'entrata e l'uscita son in 2 anni diversi, "spezzo" l'ingresso considerando solo l'anno di uscita

            -- mi interessa il tempo medio riferito all'anno di uscita, quindi l'ingresso "inizia" al mese di Gennaio
            var_meseEntrata := 1;
            -- estraggo il mese di uscita
            var_meseUscita := EXTRACT(MONTH FROM row_ingressi.orauscita);

            -- ottengo il primo giorno del mese di uscita
            var_primoGiorno := TRUNC(row_ingressi.orauscita , 'MM');

            FOR i IN var_meseEntrata .. var_meseUscita
            LOOP
                -- scorro tra i vari mesi di permanenza per calcolare i tempi

                IF i = var_meseUscita THEN
                    -- sono nel mese in cui il cliente esce

                    -- aggiungo una parte di secondi al mese di uscita
                    var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                        ((CAST(row_ingressi.orauscita AS DATE) - var_primoGiorno) * 86400);
                ELSE
                    -- tutti gli altri mesi

                    -- aggiungo TUTTI i secondi al mese.
                    var_calcoloSecondi(i) := var_calcoloSecondi(i) +
                        (CAST(TO_CHAR(LAST_DAY(TO_DATE(i, 'MM')),'DD') AS INT) * 86400);
                END IF;

                -- +1 al contatore degli ingressi per il mese i
                var_contatoriIngressi(i) := var_contatoriIngressi(i) + 1;
            END LOOP;
        END IF;
    END LOOP;

    FOR i IN 1..12
    LOOP
        -- calcolo la media per ogni mese rispetto al numero di ingressi di quel mese
        IF (var_contatoriIngressi(i) != 0) THEN
            var_calcoloSecondi(i) := TRUNC(var_calcoloSecondi(i) / var_contatoriIngressi(i));
        END IF;
    END LOOP;

    RETURN var_calcoloSecondi;
END calcoloTempoMese;

/*
    calcola il tempo medio di permanenza degli ingressi, secondo le fasce orarie, che sono stati fatti in una determinata
    autorimessa e in un periodo di tempo che include l'anno passato come input

    @param(var_autorimessa): indirizzo dell'autorimessa di cui mi interessano gli ingressi orari
    @param(var_anno): anno di cui mi interessano gli ingressi orari
    @return: array di 12 posizioni contentente la media, in secondi, per ogni fascia oraria degli ingressi con anno specificato
        da var_anno
*/
FUNCTION calcoloTempoFascia(var_autorimessa VARCHAR2, var_anno VARCHAR2) RETURN nested_fasce IS
    CURSOR cur_ingressi IS
    SELECT aree.idArea, oraentrata, orauscita
        FROM ingressiorari
        INNER JOIN box ON ingressiorari.idbox = box.idbox
        INNER JOIN aree ON box.idarea = aree.idarea
        INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
        WHERE
            -- vengono considerati solamente gli ingressi portati a termine!!!
            orauscita IS NOT NULL AND
            -- considero solamente gli ingressi effettuati nell'autorimessa di indirizzo specificato da var_autorimessa
            autorimesse.indirizzo = var_autorimessa AND
            -- considero solo gli ingressi che hanno l'anno di entrata o uscita uguale a quello specificato in var_anno
            -- vengono considerati sia ingressi orari con prenotazione che senza
            (var_anno = EXTRACT(YEAR FROM oraentrata) OR var_anno = EXTRACT(YEAR FROM orauscita)) AND
            ingressiorari.cancellato = 'F';

    -- array che conterra' la media per ogni mese in secondi
    var_calcoloSecondi nested_fasce := nested_fasce();
    -- array che conterra' il numero di ingressi per quel mese, nel caso di ingressi a cavallo tra piÃ¹ fasce si considera
    -- un ingresso per ogni fascia "attraversata"
    var_contatoriIngressi nested_fasce := nested_fasce();

    -- conterra' l'anno in cui avviene l'entrata
    var_annoEntrata INTEGER;
    -- conterra' l'anno in cui avviene l'uscita
    var_annoUscita INTEGER;

    -- conterra' la componente dell'ora in cui viene effettuata l'entrata (trasformata in secondi)
    var_oraEntrata INTEGER;
    -- conterra' la componente dell'ora in cui viene effettuata l'uscita (trasformata in secondi)
    var_oraUscita INTEGER;

    -- conterra' l'ora di inizio della fascia oraria (trasformata in secondi)
    var_oraInizioFascia INTEGER;
    -- conterra' l'ora di fine della fascia oraria (trasformata in secondi)
    var_oraFineFascia INTEGER;

    -- conterra' il numero di giorni che intercorrono tra l'entrata e l'uscita
    var_giorni INTEGER;

    -- conterra' il giorno da analizzare (per capire la/e fascia/e di appartenenza)
    var_giornoCorrente TIMESTAMP;

    var_numeroFasce INTEGER;
BEGIN
    SELECT COUNT(*) INTO var_numeroFasce
    FROM fasceOrarie;

    FOR i IN 1 .. var_numeroFasce
    LOOP
        -- inizializzo la collezione che conterra' la media
        var_calcoloSecondi.extend();
        var_calcoloSecondi(i) := 0;

        -- inizializzo la collezione che conterra' il numero di ingressi per ogni fascia
        var_contatoriIngressi.extend();
        var_contatoriIngressi(i) := 0;
    END LOOP;

    FOR row_ingressi IN cur_ingressi
    LOOP
        -- inizializzo var_giornoCorrente al timestamp di entrata
        var_giornoCorrente := row_ingressi.oraEntrata;

        -- anno in cui viene effettuata l'entrata
        var_annoEntrata := EXTRACT(YEAR FROM row_ingressi.oraEntrata);
        -- anno in cui viene effettuata l'uscita
        var_annoUscita := EXTRACT(YEAR FROM row_ingressi.oraUscita);

        IF var_annoEntrata = var_annoUscita THEN
            -- sono nel caso in cui l'entrata e l'uscita avvengono nello stesso anno

            -- Calcolo la differenza in giorni tra il timestamp di uscita e entrata
            -- Occorre eliminare la componente dell'ora perche' avrei errore di tipo ad assegnarlo a un INTEGER
            -- Occorre castare a DATE perche' la differenza tra due TIMESTAMP da un tipo INTERVAL
            var_giorni := TO_DATE(TO_CHAR(row_ingressi.oraUscita, 'DD-MON-RR'), 'DD-MON-RR') -
                    TO_DATE(TO_CHAR(row_ingressi.oraEntrata, 'DD-MON-RR'), 'DD-MON-RR');
        ELSIF var_annoEntrata = var_anno THEN
            -- sono nel caso in cui l'entrata e l'uscita avvengono in anni diversi, l'anno da considerare e' quello di
            -- entrata

            -- Considero l'ingresso come se terminasse a Dicembre
            -- Calcolo la differenza tra il 31 Dicembre e il timestamp di entrata
            -- Occorre eliminare la componente dell'ora perche' avrei errore di tipo ad assegnarlo a un INTEGER
            -- Occorre castare a DATE perche' la differenza tra due TIMESTAMP da un tipo INTERVAL
            var_giorni := TO_DATE('31-DIC-' || var_anno, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian') -
                    TO_DATE(TO_CHAR(row_ingressi.oraEntrata, 'DD-MON-RR'), 'DD-MON-RR');
        ELSIF var_annoUscita = var_anno THEN
            -- sono nel caso in cui l'entrata e l'uscita avvengono in anni diversi, l'anno da considerare e' quello di
            -- uscita

            -- Considero l'ingresso come se iniziasse a Gennaio
            -- Calcolo la differenza tra il timestamp di uscita e il 1 Gennaio
            -- Occorre eliminare la componente dell'ora perche' avrei errore di tipo ad assegnarlo a un INTEGER
            -- Occorre castare a DATE perche' la differenza tra due TIMESTAMP da un tipo INTERVAL
            var_giorni := TO_DATE(TO_CHAR(row_ingressi.oraUscita, 'DD-MON-RR'), 'DD-MON-RR') -
                    TO_DATE('1-GEN-' || var_anno, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian');
        END IF;

        FOR i IN 0 .. var_giorni
        LOOP
            -- scorro tra tutti i giorni di permanenza

            IF var_giorni = 0 AND var_annoEntrata = var_annoUscita THEN
                -- caso in cui l'entrata e l'uscita avvengono nello stesso giorno, stesso anno

                -- calcolo l'ora di entrata in secondi
                var_oraEntrata := convertiOraInSecondi(row_ingressi.oraEntrata);
                -- calcolo l'ora di uscita in secondi
                var_oraUscita := convertiOraInSecondi(row_ingressi.oraUscita);
            ELSIF i = 0 AND var_annoEntrata = var_anno THEN
                -- caso in cui l'entrata e l'uscita avvengono in giorni diversi e mi interessa l'anno di entrata,
                -- sto considerando il primo giorno

                -- calcolo l'ora di entrata in secondi
                var_oraEntrata := convertiOraInSecondi(row_ingressi.oraentrata);
                -- ora di uscita, in secondi, in questo caso corrisponde a 86399 (23:59:59)
                var_oraUscita := 86399;
            ELSIF i = var_giorni AND var_annoUscita = var_anno THEN
                -- caso in cui l'entrata e l'uscita avvengono in giorni diversi e mi interessa l'anno di uscita,
                -- sto considerando l'ultimo giorno

                -- ora di entrata in questo caso corrisponde a zero
                var_oraEntrata := 0;
                -- calcolo l'ora di uscita in secondi
                var_oraUscita := convertiOraInSecondi(row_ingressi.orauscita);
            ELSE
                -- caso in cui l'entrata e l'uscita avvengono in giorni diversi, sto considerando il giorno nel mezzo

                -- ora di entrata, in secondi, in questo caso corrisponde a zero
                var_oraEntrata := 0;
                -- ora di uscita, in secondi, in questo caso corrisponde a 86399 (23:59:59)
                var_oraUscita := 86399;
            END IF;
                FOR row_fasce IN (SELECT fasceorarie.idfasciaoraria, fasceorarie.nome, orainizio, orafine, giorno
                                    FROM fasceorarie 
                                    INNER JOIN areefasceorarie ON fasceorarie.idfasciaoraria = areefasceorarie.idfasciaoraria
                                    WHERE TO_CHAR(var_giornoCorrente, 'DY', 'NLS_DATE_LANGUAGE = italian') = giorno AND
                                        areefasceorarie.idArea = row_ingressi.idArea)
                LOOP
                    -- scorro tra tutte le fasce valide per quel determinato giorno

                    -- ora di inizio della fascia, espressa in secondi
                    var_oraInizioFascia := convertiOraInSecondi(row_fasce.oraInizio);
                    -- ora di fine della fascia, espressa in secondi
                    var_oraFineFascia := convertiOraInSecondi(row_fasce.oraFine);

                    IF (var_oraEntrata >= var_oraInizioFascia AND var_oraUscita <= var_oraFineFascia) THEN
                        -- caso in cui l'entrata e l'uscita avvengono nella stessa fascia oraria

                        -- aggiungo tutti i secondi dell'ingresso a quella fascia
                        var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria)
                            + var_oraUscita - var_oraEntrata;

                        -- +1 al contatore degli ingressi della fascia
                        var_contatoriIngressi(row_fasce.idfasciaoraria) := var_contatoriIngressi(row_fasce.idfasciaoraria) + 1;
                    ELSIF (var_oraEntrata >= var_oraInizioFascia AND var_oraEntrata <= var_oraFineFascia) THEN
                        -- caso in cui l'entrata avviene in una fascia oraria diversa da quella di uscita

                        -- aggiungo solamente la parte iniziale dell'ingresso a quella fascia
                        var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria)
                            + var_oraFineFascia - var_oraEntrata;

                        -- +1 al contatore degli ingressi della fascia
                        var_contatoriIngressi(row_fasce.idfasciaoraria) := var_contatoriIngressi(row_fasce.idfasciaoraria) + 1;
                    ElSIF (var_oraUscita >= var_oraInizioFascia AND var_oraUscita <= var_oraFineFascia) THEN
                        -- caso in cui l'uscita avviene in una fascia oraria diversa da quella di entrata

                        -- aggiungo solamente la parte finale dell'ingresso a quella fascia
                        var_calcoloSecondi(row_fasce.idfasciaoraria) := var_calcoloSecondi(row_fasce.idfasciaoraria)
                            + var_oraUscita - var_oraInizioFascia;

                        -- +1 al contatore degli ingressi della fascia
                        var_contatoriIngressi(row_fasce.idfasciaoraria) := var_contatoriIngressi(row_fasce.idfasciaoraria) + 1;
                    END IF;
                END LOOP;

            -- avanzo di un giorno
            var_giornoCorrente := var_giornoCorrente + INTERVAL '1' DAY;
        END LOOP;
    END LOOP;

    FOR i IN 1 .. 12
    LOOP
        -- calcolo la media rispetto agli ingressi che si sono avuti in quella fascia
        IF (var_contatoriIngressi(i) != 0) THEN
            var_calcoloSecondi(i) := TRUNC(var_calcoloSecondi(i) / var_contatoriIngressi(i));
        END IF;
    END LOOP;

    RETURN var_calcoloSecondi;
END calcoloTempoFascia;

PROCEDURE dettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Visualizza dettagli ingressi maggiori di X giorni', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('VISUALIZZA DETTAGLI INGRESSI MAGGIORI DI X GIORNI');
    modGUI.chiudiIntestazione(2);
    
    modGUI.apriDiv;

    modGUI.apriForm('gruppo1.visualizzaDettagliXGiorni');

    modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
    modGUI.inserisciInputHidden('nome', nome);
    modGUI.inserisciInputHidden('ruolo', ruolo);

    -- input del numero di giorni che si andranno a considerare per gli ingressi
    modGUI.inserisciInput('var_giorni', 'Giorni', 'number', TRUE);

    modGUI.inserisciBottoneReset;
    modGUI.inserisciBottoneForm('RICERCA');
    modGUI.chiudiForm;

    modGUI.chiudiDiv;

    modGUI.chiudiPagina;
END dettagliXGiorni;

PROCEDURE permanenzaNonAbbonati(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Statistiche permanenza', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('TEMPO MEDIO PERMANENZA NON ABBONATI');
    modGUI.chiudiIntestazione(2);
    
    IF ruolo = 'A' OR ruolo = 'S' THEN
        DECLARE
            CURSOR cur_autorimesse IS
                SELECT autorimesse.indirizzo
                FROM autorimesse
                ORDER BY autorimesse.indirizzo;
                    
            -- l'amministratore e superuser potranno vedere tutti gli anni degli ingressi.
            CURSOR cur_anni IS
                SELECT DISTINCT EXTRACT(YEAR FROM oraentrata) AS anno
                FROM ingressiorari
                WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
                UNION
                SELECT DISTINCT EXTRACT(YEAR FROM orauscita) AS anno
                FROM ingressiOrari
                WHERE oraentrata IS NOT NULL AND oraUscita IS NOT NULL;
                    
            row_anno cur_anni%ROWTYPE;
        BEGIN
            OPEN cur_anni;
            FETCH cur_anni INTO row_anno;
                
            IF cur_anni%ROWCOUNT = 0 THEN
                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('Non ci sono ingressi registrati per nessuna autorimessa');
                modGUI.chiudiIntestazione(3);
                modGUI.chiudiPagina;
                CLOSE cur_anni;
                RETURN;
            END IF;
            modGUI.apriDiv;
            modGUI.apriForm('gruppo1.visualizzaPermanenza');
            modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
            modGUI.inserisciInputHidden('nome', nome);
            modGUI.inserisciInputHidden('ruolo', ruolo);
                
            modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
                FOR row_autorimessa IN cur_autorimesse
                LOOP     
                    modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
                END LOOP;
            modGUI.chiudiSelect;
            
            modGUI.apriSelect('var_anno', 'ANNO');
                LOOP
                    modGUI.inserisciOpzioneSelect(row_anno.anno, row_anno.anno, FALSE);
                    
                    FETCH cur_anni INTO row_anno;
                    EXIT WHEN cur_anni%NOTFOUND;
                END LOOP;
            modGUI.chiudiSelect;
            CLOSE cur_anni;
        END;
    ELSIF ruolo = 'R' THEN
        DECLARE
            var_idSede INTEGER;
        BEGIN
            SELECT sedi.idSede INTO var_idSede
            FROM sessioni
            INNER JOIN persone ON sessioni.idpersona = persone.idpersona
            INNER JOIN dipendenti ON persone.idpersona = dipendenti.idpersona
            INNER JOIN sedi ON dipendenti.iddipendente = sedi.iddipendente
            WHERE permanenzanonabbonati.nome = persone.nome AND sessioni.ruolo = 'R' AND
                permanenzaNonAbbonati.id_Sessione = sessioni.idSessione;
            
            DECLARE
                CURSOR cur_autorimesse IS
                    SELECT autorimesse.indirizzo
                    FROM autorimesse
                    WHERE var_idSede = autorimesse.idSede
                    ORDER BY autorimesse.indirizzo;
                
                -- i responsabili potranno vedere solamente gli anni degli ingressi alle autorimesse collegate alla sede
                -- gestita
                CURSOR cur_anni IS
                    SELECT anno FROM 
                    (
                        SELECT DISTINCT idBox, EXTRACT(YEAR FROM oraentrata) AS anno
                        FROM ingressiorari
                        WHERE orauscita IS NOT NULL
                        UNION
                        SELECT DISTINCT idBox,EXTRACT(YEAR FROM orauscita) AS anno
                        FROM ingressiOrari
                        WHERE oraentrata IS NOT NULL
                    ) prova
                    INNER JOIN box ON prova.idbox = box.idbox
                    INNER JOIN aree ON box.idarea = aree.idarea
                    INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
                    WHERE var_idSede = autorimesse.idSede
                    GROUP BY anno
                    ORDER BY anno;
                    
                row_anno cur_anni%ROWTYPE;
            BEGIN
                OPEN cur_anni;
                FETCH cur_anni INTO row_anno;
                
                IF cur_anni%ROWCOUNT = 0 THEN
                    modGUI.apriIntestazione(3);
                        modGUI.inserisciTesto('Non ci sono ingressi registrati per le autorimesse del responsabile');
                    modGUI.chiudiIntestazione(3);
                    modGUI.chiudiPagina;
                    CLOSE cur_anni;
                    RETURN;
                END IF;
                modGUI.apriDiv;
                modGUI.apriForm('gruppo1.visualizzaPermanenza');
                modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
                modGUI.inserisciInputHidden('nome', nome);
                modGUI.inserisciInputHidden('ruolo', ruolo);
                
                modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
                    FOR row_autorimessa IN cur_autorimesse
                    LOOP     
                        modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);  
                    END LOOP;
                modGUI.chiudiSelect;
                
                modGUI.apriSelect('var_anno', 'ANNO');
                    LOOP
                        modGUI.inserisciOpzioneSelect(row_anno.anno, row_anno.anno, FALSE);
                        
                        FETCH cur_anni INTO row_anno;
                        EXIT WHEN cur_anni%NOTFOUND;
                    END LOOP;
                modGUI.chiudiSelect;
                CLOSE cur_anni;
            END;
            
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    modGUI.apriIntestazione(3);
                        modGUI.inserisciTesto('Il responsabile non gestisce nessuna sede');
                    modGUI.chiudiIntestazione(3);
                    modGUI.chiudiPagina;
                    RETURN;
        END;
    END IF;
    
    modGUI.inserisciTesto('MEDIA PER:');
    modGUI.aCapo;
    modGUI.inserisciRadioButton('MESE', 'var_tipo', '0', true);
    modGUI.inserisciRadioButton('FASCIA ORARIA', 'var_tipo', '1', false);
    modGUI.inserisciRadioButton('CLIENTE', 'var_tipo', '2', false);

    modGUI.inserisciBottoneReset;
    modGUI.inserisciBottoneForm('CALCOLA MEDIA');
    modGUI.chiudiForm;    
    
    modGUI.chiudiDiv;
    
    modGUI.chiudiPagina;
END permanenzaNonAbbonati;

PROCEDURE areeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Visualizza associazioni aree con fasce', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('VISUALIZZA ASSOCIAZIONI AREE CON FASCE');
    modGUI.chiudiIntestazione(2);

    IF ruolo = 'A' OR ruolo = 'S' OR ruolo = 'C' THEN
        modGUI.apriDiv;
        modGUI.apriForm('gruppo1.visualizzaAreeFasce');
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        -- l'amministrator, super user e i clienti potranno vedere informazioni su tutte le aree
        modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
        modGUI.inserisciOpzioneSelect('', '-- Tutte le autorimesse --');
        FOR row_autorimessa IN (SELECT indirizzo
                                    FROM autorimesse)
        LOOP
            modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
        END LOOP;
        modGUI.chiudiSelect;
    ELSIF ruolo = 'R' THEN
        DECLARE
            var_idSede INTEGER;
        BEGIN
            SELECT sedi.idSede INTO var_idSede
            FROM sessioni
            INNER JOIN persone ON sessioni.idpersona = persone.idpersona
            INNER JOIN dipendenti ON persone.idpersona = dipendenti.idpersona
            INNER JOIN sedi ON dipendenti.iddipendente = sedi.iddipendente
            WHERE areefasce.nome = persone.nome AND sessioni.ruolo = 'R' AND areefasce.id_Sessione = sessioni.idSessione;
            
            DECLARE
                -- i responsabili potranno vedere solamente le autorimesse collegate alla loro sede
                CURSOR cur_autorimesse IS
                    SELECT autorimesse.indirizzo
                    FROM sedi
                    INNER JOIN autorimesse ON sedi.idSede = autorimesse.idsede
                    WHERE autorimesse.idSede = var_idSede;
              
                row_autorimessa cur_autorimesse%ROWTYPE;
            BEGIN
                OPEN cur_autorimesse;
                FETCH cur_autorimesse INTO row_autorimessa;
                  
                IF cur_autorimesse%ROWCOUNT = 0 THEN
                    modGUI.apriIntestazione(3);
                        modGUI.inserisciTesto('La sede del responsabile non e'' associata a nessuna autorimessa');
                    modGUI.chiudiIntestazione(3);
                    
                    modGUI.chiudiPagina;
                    RETURN;
                END IF;
                modGUI.apriDiv;
                modGUI.apriForm('gruppo1.visualizzaAreeFasce');
                modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
                modGUI.inserisciInputHidden('nome', nome);
                modGUI.inserisciInputHidden('ruolo', ruolo);
                
                modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
                LOOP
                    modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
                      
                    FETCH cur_autorimesse INTO row_autorimessa;
                    EXIT WHEN cur_autorimesse%NOTFOUND;  
                END LOOP;
                modGUI.chiudiSelect;
            END;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('Il responsabile non gestisce nessuna sede');
                modGUI.chiudiIntestazione(3);
                
                modGUI.chiudiPagina;
                RETURN;
        END;
    ELSIF ruolo = 'O' THEN
        DECLARE
            -- gli operatori potranno vedere solo le autorimesse in cui lavorano
            CURSOR cur_autorimesse IS
            SELECT autorimesse.indirizzo
            FROM sessioni
            INNER JOIN persone ON sessioni.idpersona = persone.idpersona
            INNER JOIN dipendenti ON persone.idpersona = dipendenti.idpersona
            INNER JOIN autorimesse ON dipendenti.idautorimessa = autorimesse.idautorimessa
            WHERE areefasce.nome = persone.nome AND sessioni.ruolo = 'O';
          
            row_autorimessa cur_autorimesse%ROWTYPE;
        BEGIN
            OPEN cur_autorimesse;
            FETCH cur_autorimesse INTO row_autorimessa;
                    
            IF cur_autorimesse%ROWCOUNT = 0 THEN
                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('L''operatore non lavora in nessuna autorimessa');
                modGUI.chiudiIntestazione(3);
                modGUI.chiudiPagina;
                RETURN;
            END IF;
            modGUI.apriDiv;
            modGUI.apriForm('gruppo1.visualizzaAreeFasce');
            modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
            modGUI.inserisciInputHidden('nome', nome);
            modGUI.inserisciInputHidden('ruolo', ruolo);
                
            LOOP     
                modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
                modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
                  
                FETCH cur_autorimesse INTO row_autorimessa;
                EXIT WHEN cur_autorimesse%NOTFOUND;  
            END LOOP;
            modGUI.chiudiSelect;
        END;
    END IF;
    modGUI.inserisciBottoneReset;
    modGUI.inserisciBottoneForm('CERCA');

    modGUI.chiudiForm;

    modGUI.chiudiDiv;

    modGUI.chiudiPagina;
    
END areeFasce;

PROCEDURE visualizzaDettagliXGiorni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_giorni VARCHAR2) IS
    CURSOR cur_dettagli IS
    SELECT nome, cognome, indirizzo, autorimesse.idAutorimessa, clienteid
    FROM (
        SELECT persone.nome, persone.cognome, clienti.idcliente AS clienteid, idbox
        FROM clienti
        INNER JOIN persone ON clienti.idpersona = persone.idpersona
        INNER JOIN effettuaingressiorari ON effettuaingressiorari.idcliente = clienti.idcliente
        INNER JOIN ingressiorari ON effettuaingressiorari.idingressoorario = ingressiorari.idingressoorario
        WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL AND ingressiorari.cancellato = 'F'
        UNION
        SELECT persone.nome, persone.cognome, clienti.idcliente AS clienteid, idbox
        FROM clienti
        INNER JOIN persone ON clienti.idpersona = persone.idpersona
        INNER JOIN effettuaIngressiAbbonamenti ON clienti.idcliente = effettuaingressiabbonamenti.idcliente
        INNER JOIN ingressiabbonamenti ON effettuaingressiabbonamenti.idingressoabbonamento = ingressiabbonamenti.idingressoabbonamento
        WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
    ) tabApp
    INNER JOIN box ON tabApp.idbox = box.idbox
    INNER JOIN aree ON box.idarea = aree.idarea
    INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
    WHERE clienteid NOT IN (SELECT idCliente
                                    FROM effettuaingressiorari
                                    INNER JOIN ingressiorari
                                        ON effettuaingressiorari.idingressoorario = ingressiorari.idingressoorario
                                    WHERE ((CAST(orauscita AS DATE) - CAST(oraentrata AS DATE))) <= var_giorni) AND
        clienteid NOT IN (SELECT idCliente
                                    FROM effettuaIngressiAbbonamenti
                                    INNER JOIN ingressiabbonamenti
                                        ON effettuaingressiabbonamenti.idingressoabbonamento = ingressiabbonamenti.idingressoabbonamento
                                    WHERE ((CAST(orauscita AS DATE) - CAST(oraentrata AS DATE))) <= var_giorni)
    GROUP BY nome, cognome, indirizzo, autorimesse.idautorimessa, clienteid
    ORDER BY indirizzo;

    var_exists BOOLEAN := FALSE;
BEGIN
    modGUI.apriPagina('HoC | Visualizza dettagli ingressi maggiori di X giorni', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('VISUALIZZA DETTAGLI INGRESSI MAGGIORI DI X GIORNI');
    modGUI.chiudiIntestazione(2);

    IF TO_NUMBER(var_giorni) < 0 THEN
        modGUI.apriDiv;
            modGUI.esitoOperazione('KO', 'Numero giorni non valido');
        modGUI.chiudiDiv;
        
        modGUI.apriIntestazione(3);
            modGUI.inserisciTesto('ALTRE OPERAZIONI');
        modGUI.chiudiIntestazione(3);
        modGUI.apriDiv(TRUE);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.dettagliXgiorni');
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
        RETURN;
    END IF;
    
    modGUI.apriDiv;

    modGUI.apriTabella;
    modGUI.apriRigaTabella;
        modGUI.intestazioneTabella('CLIENTE');
        modGUI.intestazioneTabella('DETTAGLI CLIENTE');
        modGUI.intestazioneTabella('AUTORIMESSE');
        modGUI.intestazioneTabella('DETTAGLI AUTORIMESSA');
    modGUI.chiudiRigaTabella;

    FOR row_dettagli IN cur_dettagli
    LOOP
        var_exists := TRUE;
        modGUI.apriRigaTabella;
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(row_dettagli.nome || ' ' || row_dettagli.cognome);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo5.moreInfoClient', id_Sessione, nome, ruolo, row_dettagli.clienteid);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.elementoTabella(row_dettagli.indirizzo);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo2.visualizzaAutorimessa', id_Sessione, nome, ruolo, row_dettagli.idAutorimessa);
            modGUI.chiudiElementoTabella;
        modGUI.chiudiRigaTabella;
    END LOOP;
    modGUI.chiudiTabella;
    modGUI.chiudiDiv;

    IF NOT var_exists THEN
        modGUI.apriDiv(TRUE);
            modGUI.inserisciTesto('Nessun dato da visualizzare');
        modGUI.chiudiDiv;
        modGUI.aCapo;
    END IF;

    modGUI.apriIntestazione(3);
	    modGUI.inserisciTesto('ALTRE OPERAZIONI');
	modGUI.chiudiIntestazione(3);
    modGUI.apriDiv(TRUE);
        modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.dettagliXgiorni');
    modGUI.chiudiDiv;
    
    modGUI.chiudiPagina;
END visualizzaDettagliXGiorni;

PROCEDURE visualizzaPermanenza(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2, var_anno VARCHAR2,
    var_tipo VARCHAR2) IS
        
    var_giorni INTEGER;
    var_ore INTEGER;
    var_minuti INTEGER;
BEGIN
    modGUI.apriPagina('HoC | Statistiche permanenza', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('TEMPO MEDIO PERMANENZA NON ABBONATI');
    modGUI.chiudiIntestazione(2);

    modGUI.apriIntestazione(3);
        modGUI.inserisciTesto('AUTORIMESSA DI RIFERIMENTO: ');
        DECLARE
            var_idAutorimessa INTEGER;
        BEGIN
            SELECT idAutorimessa INTO var_idAutorimessa
            FROM autorimesse
            WHERE indirizzo = var_autorimessa;
            
            modGUI.collegamento(var_autorimessa, 'gruppo2.visualizzaAutorimessa?id_Sessione=' || id_Sessione || '&nome=' ||
                nome || '&ruolo=' || ruolo || '&idRiga=' || var_idAutorimessa);
        END;
        modGUI.aCapo;
        modGUI.inserisciTesto('ANNO DI RIFERIMENTO: ');
        modGUI.collegamento(var_anno,
                            'gruppo1.visualizzaCronologia?id_Sessione=' || id_sessione || '&nome=' || nome || '&ruolo=' || ruolo ||
                            '&var_autorimessa=' || var_autorimessa || '&var_cliente=' || '&var_targa=' || '&var_dataInizio=' ||
                            var_anno || '-1-1' || '&var_dataFine=' || var_anno || '-12-31');
    modGUI.chiudiIntestazione(3);
    
    modGUI.apriDiv;

    IF var_tipo = 0 THEN
        DECLARE
            var_calcoloSecondi array_int := array_int();
        BEGIN
            var_calcoloSecondi := calcoloTempoMese(var_autorimessa, var_anno);
    
            modGUI.apriTabella;
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
        
                    modGUI.apriRigaTabella;
                        modGUI.apriElementoTabella;
                            IF NOT var_show THEN
                                modGUI.ElementoTabella(TO_CHAR(TO_DATE(i, 'MM'), 'Month', 'NLS_DATE_LANGUAGE = italian'));
                            ELSE
                                -- se ci sono stati ingressi per quel mese inserisco un collegamento per farli visualizzare
                                modGUI.collegamento(TO_CHAR(TO_DATE(i, 'MM'), 'Month', 'NLS_DATE_LANGUAGE = italian'),
                                    'gruppo1.visualizzaCronologia?id_Sessione=' || id_sessione || '&nome=' || nome || '&ruolo=' 
                                    || ruolo || '&var_autorimessa=' || var_autorimessa || '&var_cliente=' || '&var_targa=' || 
                                    '&var_dataInizio=' || var_anno || '-' || i || '-1' || '&var_dataFine=' ||
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
        END;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
    ELSIF var_tipo = 1 THEN
        DECLARE
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
                    END, orainizio ASC, oraFine ASC;
                        var_calcoloSecondi nested_fasce := nested_fasce();
            row_fascia cur_fasce%ROWTYPE;
        BEGIN
            OPEN cur_fasce;
            FETCH cur_fasce INTO row_fascia;
            
            IF cur_fasce%ROWCOUNT = 0 THEN
                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('Non ci sono ancora fasce orarie');
                modGUI.chiudiIntestazione(3);

                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('ALTRE OPERAZIONI');
                modGUI.chiudiIntestazione(3);
                modGUI.apriDiv(TRUE);
                    modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.permanenzaNonAbbonati');
                modGUI.chiudiDiv;
                modGUI.chiudiPagina;
                CLOSE cur_fasce;
                RETURN;
            END IF;
            var_calcoloSecondi := calcoloTempoFascia(var_autorimessa, var_anno);
    
            modGUI.apriTabella;
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('FASCIA');
                modGUI.intestazioneTabella('DETTAGLIO FASCIA');
                modGUI.intestazioneTabella('GIORNI');
                modGUI.intestazioneTabella('ORE');
                modGUI.intestazioneTabella('MINUTI');
                modGUI.intestazioneTabella('SECONDI');
            modGUI.chiudiRigaTabella;
    
            LOOP
                var_minuti := TRUNC(var_calcoloSecondi(row_fascia.idfasciaoraria) / 60);
                var_calcoloSecondi(row_fascia.idfasciaoraria) := var_calcoloSecondi(row_fascia.idfasciaoraria) - (var_minuti * 60);
    
                var_ore := TRUNC(var_minuti / 60);
                var_minuti := var_minuti - (var_ore * 60);
    
                var_giorni := TRUNC(var_ore / 24);
                var_ore := var_ore - (var_giorni * 24);
    
                modGui.apriRigaTabella;
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(row_fascia.nome);
                    modGUI.chiudiElementoTabella;
    
                    modGUI.apriElementoTabella;
                        modGUI.inserisciLente('gruppo1.dettaglioFascia', id_Sessione, nome, ruolo, row_fascia.idFasciaoraria);
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
                        modGUI.elementoTabella(var_calcoloSecondi(row_fascia.idfasciaoraria));
                    modGUI.chiudiElementoTabella;
                modGUI.chiudiRigaTabella;
                
                FETCH cur_fasce INTO row_fascia;
                EXIT WHEN cur_fasce%NOTFOUND;
            END LOOP;
        END;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
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
                                    ELSE TO_DATE('31-DIC-' || var_anno || ' 23:59:59', 'DD-MON-RR HH24:MI:SS', 'NLS_DATE_LANGUAGE = italian')
                                    END)
                            -
                            (CASE WHEN EXTRACT(YEAR FROM oraEntrata) = var_anno
                                    THEN CAST(oraEntrata AS DATE)
                                    ELSE TO_DATE('1-GEN-' || var_anno || ' 0:0:0', 'DD-MON-RR HH24:MI:SS','NLS_DATE_LANGUAGE = italian')
                                    END))
                            * 86400) AS media
                    FROM clienti
                    INNER JOIN persone ON clienti.idPersona = persone.idpersona
                    INNER JOIN effettuaingressiorari ON clienti.idcliente = effettuaingressiorari.idcliente
                    INNER JOIN ingressiorari ON effettuaingressiorari.idingressoorario = ingressiorari.idingressoorario
                    INNER JOIN box ON ingressiorari.idBox = box.idBox
                    INNER JOIN aree ON box.idArea = aree.idArea
                    INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
                    WHERE (EXTRACT(YEAR FROM oraentrata) = var_anno OR EXTRACT (YEAR FROM orauscita) = var_anno) AND
                        autorimesse.indirizzo = var_autorimessa AND ingressiorari.cancellato = 'F' AND
                        oraentrata IS NOT NULL AND orauscita IS NOT NULL
                    GROUP BY clienti.idCliente, codiceFiscale, nome, cognome
                    ORDER BY nome, cognome;

                var_exists BOOLEAN := FALSE;
            BEGIN
            modGUI.apriTabella;
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
                var_exists := TRUE;
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
                            'gruppo1.visualizzaCronologia?id_Sessione=' || id_sessione || '&nome=' || nome || '&ruolo=' || ruolo ||
                            '&var_autorimessa=' || var_autorimessa || '&var_cliente=' || row_media.codicefiscale || '&var_targa=' || 
                            '&var_dataInizio=' || var_anno || '-1-1' || '&var_dataFine=' || '2019-12-31');
                    modGUI.chiudiElementoTabella;
                    modGUI.apriElementoTabella;
                        modGUI.inserisciLente('gruppo5.moreInfoClient', id_Sessione, nome, ruolo, row_media.idCliente);
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
            modGUI.chiudiTabella;
            modGUI.chiudiDiv;
            IF NOT var_exists THEN
                modGUI.apriDiv(TRUE);
                    modGUI.inserisciTesto('Nessun dato da visualizzare');
                modGUI.chiudiDiv;
                modGUI.aCapo;
            END IF;
        END;
    END IF;

    modGUI.apriIntestazione(3);
	    modGUI.inserisciTesto('ALTRE OPERAZIONI');
	modGUI.chiudiIntestazione(3);
    modGUI.apriDiv(TRUE);
        modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'CALCOLA NUOVA MEDIA', 'gruppo1.permanenzaNonAbbonati');
    modGUI.chiudiDiv;

    modGUI.chiudiPagina;
END visualizzaPermanenza;

PROCEDURE percentualePrenotazioni(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
-- solo amministratore e super user
BEGIN
    modGUI.apriPagina('HoC | Percentuale prenotazioni', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('PERCENTUALE PRENOTAZIONI');
    modGUI.chiudiIntestazione(2);
    
    DECLARE         
        CURSOR cur_anni IS
            -- l'amministratore e il super user potranno vedere tutti gli anni in cui sono stati effettuati ingressi
            SELECT DISTINCT EXTRACT(YEAR FROM oraentrata) AS anno
            FROM ingressiorari
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL
            UNION
            SELECT DISTINCT EXTRACT(YEAR FROM orauscita) AS anno
            FROM ingressiOrari
            WHERE oraentrata IS NOT NULL AND orauscita IS NOT NULL; 
            
        row_anno cur_anni%ROWTYPE;
    BEGIN
        OPEN cur_anni;
        FETCH cur_anni INTO row_anno;
                
        IF cur_anni%ROWCOUNT = 0 THEN
            modGUI.apriIntestazione(3);
                modGUI.InserisciTesto('Non ci sono ingressi registrati');
            modGUI.chiudiIntestazione(3);
            modGUI.chiudiPagina;
            CLOSE cur_anni;
            RETURN;
        END IF;
        modGUI.apriDiv;
        modGUI.apriForm('gruppo1.visualizzaPercentuale');
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        
        modGUI.apriSelect('var_anno', 'ANNO');
            LOOP
                modGUI.inserisciOpzioneSelect(row_anno.anno, row_anno.anno, FALSE);
                
                FETCH cur_anni INTO row_anno;
                EXIT WHEN cur_anni%NOTFOUND;
            END LOOP;
        modGUI.chiudiSelect;
        CLOSE cur_anni;
    END;
        
    modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
    modGUI.inserisciInputHidden('nome', nome);
    modGUI.inserisciInputHidden('ruolo', ruolo);

    modGUI.inserisciTesto('PERCENTUALE PER:');
    modGUI.aCapo;
    modGUI.inserisciRadioButton('AUTORIMESSA', 'var_tipo', '0', true);
    modGUI.inserisciRadioButton('CLIENTE', 'var_tipo', '1', false);
    
    modGUI.inserisciBottoneReset;
    modGUI.inserisciBottoneForm('CALCOLA');
    modGUI.chiudiForm;
        
    modGUI.chiudiDiv;
    modGUI.chiudiPagina;
END percentualePrenotazioni;

PROCEDURE visualizzaPercentuale(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_anno VARCHAR2, var_tipo VARCHAR2) IS
-- solo amministratore e super user
    prenotazione rec_prenot;
BEGIN
    modGUI.apriPagina('HoC | Percentuale prenotazioni', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    IF var_tipo = 0 THEN
        DECLARE
            CURSOR cur_autorimesse IS
                SELECT idautorimessa, indirizzo
                FROM autorimesse
                ORDER BY indirizzo ASC;

            var_exists BOOLEAN := FALSE;            
        BEGIN
            modGUI.apriIntestazione(2);
                modGUI.inserisciTesto('PERCENTUALE PER AUTORIMESSE');
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
            var_exists := TRUE;
            modGUI.apriRigaTabella;

            -- INDIRIZZO + DETTAGLI DELL'AUTORIMESSA --
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(row_autorimesse.indirizzo);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo2.visualizzaAutorimessa', id_Sessione, nome, ruolo, row_autorimesse.idAutorimessa);
            modGUI.chiudiElementoTabella;

            -- NUMERO DI INGRESSI TOTALI --
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(prenotazione.var_totale);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.elementoTabella(prenotazione.var_conPrenotazione);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.elementoTabella(prenotazione.var_senzaPrenotazione);
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
        modGUI.chiudiDiv;
        IF NOT var_exists THEN
            modGUI.apriDiv(TRUE);
                modGUI.inserisciTesto('Nessun dato da visualizzare');
            modGUI.chiudiDiv;
        END IF;
        END;
    ELSE
        DECLARE
            CURSOR cur_persone IS
                SELECT idCliente, nome, cognome
                FROM persone
                INNER JOIN clienti ON persone.idpersona = clienti.idpersona
                ORDER BY cognome, nome ASC;
                
            var_exists BOOLEAN := FALSE;
        BEGIN
            modGUI.apriIntestazione(2);
                modGUI.inserisciTesto('PERCENTUALE PER CLIENTI');
            modGUI.chiudiIntestazione(2);
    
            modGUI.apriDiv;
            modGUI.apriTabella;
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('GENERALITA''');
                modGUI.intestazioneTabella('DETTAGLI CLIENTE');
                modGUI.intestazioneTabella('INGRESSI TOTALI');
                modGUI.intestazioneTabella('INGRESSI CON PRENOTAZIONE');
                modGUI.intestazioneTabella('INGRESSI SENZA PRENOTAZIONE');
                modGUI.intestazioneTabella('PERCENTUALE');
            modGUI.chiudiRigaTabella;
    
            FOR row_persone IN cur_persone
            LOOP
                prenotazione := calcoloInfoPrenotCliente(row_persone.idcliente, var_anno);
                var_exists := TRUE;
                modGUI.apriRigaTabella;
    
                    -- GENERALITA' DEL CLIENTE --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(row_persone.cognome || ' ' || row_persone.nome);
                    modGUI.chiudiElementoTabella;
                    
                    -- DETTAGLI DEL CLIENTE --
                    modGUI.apriElementoTabella;
                        modGUI.inserisciLente('gruppo5.moreInfoClient', id_Sessione, nome, ruolo, row_persone.idCliente);
                    modGUI.chiudiElementoTabella;
    
                    -- NUMERO DI INGRESSI TOTALI --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(prenotazione.var_totale);
                    modGUI.chiudiElementoTabella;
    
                    -- NUMERO DI PRENOTAZIONI --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(prenotazione.var_conPrenotazione);
                    modGUI.chiudiElementoTabella;
    
                    -- NUMERO DI INGRESSI SENZA PRENOTAZIONE --
                    modGUI.apriElementoTabella;
                        modGUI.elementoTabella(prenotazione.var_senzaPrenotazione);
                    modGUI.chiudiElementoTabella;
    
                    -- PERCENTUALE DI PRENOTAZIONI RISPETTO AL TOTALE
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
            modGUI.chiudiDiv;
            IF NOT var_exists THEN
                modGUI.apriDiv(TRUE);
                    modGUI.inserisciTesto('Nessun dato da visualizzare');
                modGUI.chiudiDiv;
            END IF;
        END;
    END IF;

    modGUI.apriIntestazione(3);
	modGUI.inserisciTesto('ALTRE OPERAZIONI');
    modGUI.chiudiIntestazione(3);
    modGUI.apriDiv(TRUE);
        modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'CALCOLO NUOVA PERCENTUALE', 'gruppo1.percentualePrenotazioni');
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
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.InserisciTesto('CRONOLOGIA ACCESSI');
    modGUI.chiudiIntestazione(2);

    IF (ruolo = 'A' OR ruolo = 'S') THEN
        modGUI.apriDiv;
        modGUI.apriForm('gruppo1.visualizzaCronologia');
        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        -- l'amministratore e super user potranno filtrare per qualasiasi autorimessa
        modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
        modGUI.inserisciOpzioneSelect('', '--Tutte le autorimesse--');
        
        FOR row_autorimesse IN (SELECT indirizzo
                                FROM autorimesse)
        LOOP
            modGUI.inserisciOpzioneSelect(row_autorimesse.indirizzo, row_autorimesse.indirizzo);
        END LOOP;
        modGUI.chiudiSelect;
    ELSIF ruolo = 'R' THEN
        DECLARE
            var_idSede INTEGER;
        BEGIN
            SELECT idSede INTO var_idSede
                FROM sessioni
                INNER JOIN dipendenti ON sessioni.idpersona = dipendenti.idpersona
                INNER JOIN persone ON dipendenti.idpersona = persone.idpersona
                INNER JOIN sedi ON dipendenti.idDipendente = sedi.iddipendente
                WHERE persone.nome = cronologiaAccessi.nome AND sessioni.ruolo = 'R' AND
                    sessioni.idSessione = cronologiaAccessi.id_Sessione;
            
            DECLARE
                -- il responsabile puo' filtrare solamente per le autorimesse collegate alla sua sede
                CURSOR cur_autorimesse IS
                    SELECT autorimesse.indirizzo
                    FROM sedi
                    INNER JOIN autorimesse ON sedi.idsede = autorimesse.idsede
                    WHERE sedi.idSede = var_idSede;
                
                row_autorimessa cur_autorimesse%ROWTYPE;
            BEGIN
                OPEN cur_autorimesse;
                FETCH cur_autorimesse INTO row_autorimessa;
                        
                IF cur_autorimesse%ROWCOUNT = 0 THEN
                    modGUI.apriIntestazione(3);
                        modGUI.inserisciTesto('La sede del responsabile non ha autorimesse collegate');
                    modGUI.chiudiIntestazione(3);
                    modGUI.chiudiPagina;
                    CLOSE cur_autorimesse;
                    RETURN;
                END IF;
                
                modGUI.apriDiv;
                modGUI.apriForm('gruppo1.visualizzaCronologia');
                modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
                modGUI.inserisciInputHidden('nome', nome);
                modGUI.inserisciInputHidden('ruolo', ruolo);
                
                modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
                LOOP     
                    modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
                      
                    FETCH cur_autorimesse INTO row_autorimessa;
                    EXIT WHEN cur_autorimesse%NOTFOUND;  
                END LOOP;
                modGUI.chiudiSelect;
            END;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    modGUI.apriIntestazione(3);
                        modGUI.inserisciTesto('Il responsabile non gestisce nessuna sede');
                    modGUI.chiudiIntestazione(3);
                    modGUI.chiudiPagina;
                    RETURN;
        END;
    ELSIF ruolo = 'O' THEN
        DECLARE
            -- l'operatore puo' filtrare solamente per le autorimesse in cui lavora
            CURSOR cur_autorimesse IS
            SELECT autorimesse.indirizzo
                FROM sessioni
                INNER JOIN dipendenti ON sessioni.idpersona = dipendenti.idpersona
                INNER JOIN persone ON dipendenti.idpersona = persone.idpersona
                INNER JOIN autorimesse ON dipendenti.idautorimessa = autorimesse.idautorimessa
                WHERE persone.nome = cronologiaAccessi.nome AND sessioni.ruolo = 'O' AND
                    sessioni.idSessione = cronologiaAccessi.id_Sessione;
            
            row_autorimessa cur_autorimesse%ROWTYPE;
        BEGIN
            OPEN cur_autorimesse;
            FETCH cur_autorimesse INTO row_autorimessa;
                    
            IF cur_autorimesse%ROWCOUNT = 0 THEN
                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('L''operatore non lavora in nessuna autorimessa');
                modGUI.chiudiIntestazione(3);
                modGUI.chiudiPagina;
                CLOSE cur_autorimesse;
                RETURN;
            END IF;
            
            modGUI.apriDiv;
            modGUI.apriForm('gruppo1.visualizzaCronologia');
            modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
            modGUI.inserisciInputHidden('nome', nome);
            modGUI.inserisciInputHidden('ruolo', ruolo);
            
            modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
            LOOP     
                modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
                  
                FETCH cur_autorimesse INTO row_autorimessa;
                EXIT WHEN cur_autorimesse%NOTFOUND;
                CLOSE cur_autorimesse;
            END LOOP;
            modGUI.chiudiSelect;
        END;
    ELSIF ruolo = 'C' THEN
        DECLARE
            -- il cliente puo' filtrare solamente per le autorimesse in cui ha effettuato ingressi
            CURSOR cur_autorimesse IS 
                SELECT DISTINCT autorimesse.indirizzo
                FROM sessioni
                INNER JOIN clienti ON sessioni.idpersona = clienti.idpersona
                INNER JOIN persone ON clienti.idpersona = persone.idpersona
                INNER JOIN effettuaingressiorari ON clienti.idcliente = effettuaingressiorari.idcliente
                INNER JOIN ingressiorari ON effettuaingressiorari.idingressoorario = ingressiorari.idingressoorario
                INNER JOIN box ON ingressiorari.idbox = box.idbox
                INNER JOIN aree ON box.idarea = aree.idarea
                INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
                WHERE persone.nome = cronologiaAccessi.nome AND sessioni.ruolo = 'C' AND
                    sessioni.idSessione = cronologiaAccessi.id_Sessione AND oraentrata IS NOT NULL AND orauscita IS NOT NULL
                ORDER BY autorimesse.indirizzo;
            
            row_autorimessa cur_autorimesse%ROWTYPE;
        BEGIN
            OPEN cur_autorimesse;
            FETCH cur_autorimesse INTO row_autorimessa;
                    
            IF cur_autorimesse%ROWCOUNT = 0 THEN
                modGUI.apriIntestazione(3);
                    modGUI.inserisciTesto('Il cliente non ha mai effettuato accessi con biglietto');
                modGUI.chiudiIntestazione(3);
                modGUI.chiudiPagina;
                CLOSE cur_autorimesse;
                RETURN;
            END IF;
            
            modGUI.apriDiv;
            modGUI.apriForm('gruppo1.visualizzaCronologia');
            modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
            modGUI.inserisciInputHidden('nome', nome);
            modGUI.inserisciInputHidden('ruolo', ruolo);
            
            modGUI.apriSelect('var_autorimessa', 'AUTORIMESSA');
            LOOP     
                modGUI.inserisciOpzioneSelect(row_autorimessa.indirizzo, row_autorimessa.indirizzo);
                  
                FETCH cur_autorimesse INTO row_autorimessa;
                EXIT WHEN cur_autorimesse%NOTFOUND;  
            END LOOP;
            modGUI.chiudiSelect;
            CLOSE cur_autorimesse;
        END;    
    END IF;
      
    -- codice fiscale, campo non obbligatorio
    IF ruolo != 'C' THEN
        -- se l'utente non e' un cliente espongo il campo di input per inserire un codice fiscale
        modGUI.inserisciInput('var_cliente', 'Codice Fiscale', 'text', false);
    ELSE
        -- se l'utente non e' un cliente evito di fargli inserire codici fiscali di altre persone o di nuovo il suo
        DECLARE
            var_cf CHAR(16);
        BEGIN

        SELECT codiceFiscale INTO var_cf
        FROM sessioni
        INNER JOIN persone ON sessioni.idpersona = persone.idpersona
        WHERE persone.nome = cronologiaAccessi.nome AND ruolo = 'C';

        modGUI.inserisciInputHidden('var_cliente', var_cf);

        END;
    END IF;

    -- targa, campo non obbligatorio
    modGUI.inserisciInput('var_targa', 'Targa', 'text', FALSE);

    -- data di inizio, campo obbligatorio
    modGUI.inserisciInput('var_dataInizio', 'DATA INIZIO', 'date', TRUE);

    -- data di fine, campo obbligatorio
    modGUI.inserisciInput('var_dataFine', 'DATA FINE', 'date', TRUE);

    modGUI.inserisciBottoneReset;
    modGUI.inserisciBottoneForm('CERCA');
    modGUI.chiudiForm;

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
            oraUscita >= TO_TIMESTAMP(TO_CHAR(TO_TIMESTAMP(var_dataInizio, 'YYYY-MM-DD'), 'DD-MON-RR') || ' 0:0:0', 'DD-MON-RR HH24:MI:SS') AND
            ingressiorari.cancellato = 'F'
        ORDER BY autorimesse.idAutorimessa, clienti.idCliente, veicoli.idVeicolo, oraEntrata ASC;

    var_noRecord BOOLEAN := true;
BEGIN
    modGUI.apriPagina('HoC | Cronologia Accessi', id_Sessione, nome, ruolo);
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('CRONOLOGIA ACCESSI');
    modGUI.chiudiIntestazione(2);

    modGUI.apriDiv;

    IF TO_DATE(var_dataInizio, 'YYYY-MM-DD') > TO_DATE(var_dataFine, 'YYYY-MM-DD') THEN
        modGUI.esitoOperazione('KO', 'Data inizio maggiore di data fine');
        modGUI.chiudiDiv;

        modGUI.apriIntestazione(3);
	    modGUI.inserisciTesto('ALTRE OPERAZIONI');
	modGUI.chiudiIntestazione(3);
        modGUI.apriDiv(TRUE);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.cronologiaAccessi');
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
        RETURN;
    END IF;
    
    IF var_cliente IS NOT NULL THEN
        IF LENGTH(var_cliente) != 16 THEN
            modGUI.esitoOperazione('KO', 'Codice fiscale non valido');
            modGUI.chiudiDiv;

            modGUI.apriIntestazione(3);
	        modGUI.inserisciTesto('ALTRE OPERAZIONI');
	    modGUI.chiudiIntestazione(3);
            modGUI.apriDiv(TRUE);
                modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.cronologiaAccessi');
            modGUI.chiudiDiv;
            modGUI.chiudiPagina;
            RETURN;
        END IF;
    
        IF NOT checkCliente(var_cliente) THEN
            modGUI.esitoOperazione('KO', 'Il cliente specificato non esiste');
            modGUI.chiudiDiv;
            modGUI.apriIntestazione(3);
	        modGUI.inserisciTesto('ALTRE OPERAZIONI');
	    modGUI.chiudiIntestazione(3);
            modGUI.apriDiv(TRUE);
                modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.cronologiaAccessi');
            modGUI.chiudiDiv;
            modGUI.chiudiPagina;
            RETURN;
        END IF;
    END IF;

    IF var_targa IS NOT NULL THEN
        IF LENGTH(var_targa) != 7 THEN
            modGUI.esitoOperazione('KO', 'Targa non valida');
            modGUI.chiudiDiv;

            modGUI.apriIntestazione(3);
	        modGUI.inserisciTesto('ALTRE OPERAZIONI');
	    modGUI.chiudiIntestazione(3);
            modGUI.apriDiv(TRUE);
                modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.cronologiaAccessi');
            modGUI.chiudiDiv;
            modGUI.chiudiPagina;
            RETURN;
        END IF;
        
        IF ruolo = 'C' THEN
            -- in questo modo non espongo i link alle targhe di altri clienti
            IF NOT checkTarga(var_targa, var_cliente) THEN
                modGUI.esitoOperazione('KO', 'Il veicolo specificato non e'' di proprieta'' del cliente o non esiste');
                modGUI.chiudiDiv;
                modGUI.apriIntestazione(3);
	    	    modGUI.inserisciTesto('ALTRE OPERAZIONI');
	        modGUI.chiudiIntestazione(3);    
                modGUI.apriDiv(TRUE);
                    modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.cronologiaAccessi');
                modGUI.chiudiDiv;
                modGUI.chiudiPagina;
                RETURN;
            END IF;
        ELSE
            IF NOT checkTarga(var_targa, '') THEN
                modGUI.esitoOperazione('KO', 'Il veicolo specificato non esiste');
                modGUI.chiudiDiv;
                modGUI.apriIntestazione(3);
	            modGUI.inserisciTesto('ALTRE OPERAZIONI');
	        modGUI.chiudiIntestazione(3);    
                modGUI.apriDiv(TRUE);
                    modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.cronologiaAccessi');
                modGUI.chiudiDiv;
                modGUI.chiudiPagina;
                RETURN;
            END IF;
        END IF;
    END IF;

    modGUI.apriIntestazione(3);
        modGUI.inserisciTesto('DATA DI INIZIO: ' || TO_CHAR(TO_DATE(var_dataInizio, 'YYYY-MM-DD'), 'DD-MON-YYYY', 'NLS_DATE_LANGUAGE = italian'));
        modGUI.aCapo;
        modGUI.inserisciTesto('DATA DI FINE: ' || TO_CHAR(TO_DATE(var_dataFine, 'YYYY-MM-DD'), 'DD-MON-YYYY', 'NLS_DATE_LANGUAGE = italian'));
        modGUI.aCapo;
        
        IF var_autorimessa IS NOT NULL THEN
            modGUI.inserisciTesto('AUTORIMESSA: ');
            DECLARE
                var_idAutorimessa INTEGER;
            BEGIN
                SELECT idAutorimessa INTO var_idAutorimessa
                FROM autorimesse
                WHERE indirizzo = var_autorimessa;
                    
                modGUI.collegamento(var_autorimessa, 'gruppo2.visualizzaArea?id_Sessione=' || id_Sessione || '&nome=' ||
                            nome || '&ruolo=' || ruolo || '&idRiga=' || var_idAutorimessa);
            END;
            modGUI.aCapo;
        END IF;
        
        IF var_cliente IS NOT NULL THEN
            modGUI.inserisciTesto('CLIENTE: ');
            DECLARE
                var_idCliente INTEGER;
            BEGIN
                SELECT idCliente INTO var_idCliente
                FROM clienti
                INNER JOIN persone ON clienti.idpersona = persone.idpersona
                WHERE persone.codicefiscale = var_cliente;
                    
                modGUI.collegamento(var_cliente, 'gruppo5.moreInfoClient?id_Sessione=' || id_Sessione || '&nome=' || nome || 
                    '&ruolo=' || ruolo || '&idRiga=' || var_idCliente);
                modGUI.aCapo;
            END;
        END IF;
        
        IF var_targa IS NOT NULL THEN
            modGUI.inserisciTesto('VEICOLO: ');
            DECLARE
                var_idVeicolo INTEGER;
            BEGIN
                SELECT idVeicolo INTO var_idVeicolo
                FROM veicoli
                WHERE veicoli.targa = var_targa;
                
                modGUI.collegamento(var_targa, 'gruppo5.moreInfoCar?id_Sessione=' || id_Sessione || '&nome=' || nome || '&ruolo=' 
                    || ruolo || '&idRiga=' || var_idVeicolo);
            END;
        END IF;
    modGUI.chiudiIntestazione(3);

    DECLARE
        -- variabili di controllo per organizzare le tabelle da far vedere
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
                        modGUI.collegamento(row_ingressi.indirizzo, 'gruppo2.visualizzaAutorimessa?id_Sessione=' || id_Sessione ||
                            '&nome=' || nome || '&ruolo=' || ruolo || '&idRiga=' || row_ingressi.idAutorimessa);
                END IF;
                modGUI.aCapo;

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
                    
                    modGUI.collegamento(row_ingressi.codiceFiscale, 'gruppo5.moreInfoClient?id_Sessione=' || id_Sessione ||
                        '&nome=' || nome || '&ruolo=' || ruolo || '&idRiga=' || row_ingressi.idCliente);
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
                    DECLARE
                        var_idVeicolo INTEGER;
                    BEGIN
                        SELECT idVeicolo INTO var_idVeicolo
                        FROM veicoli
                        WHERE targa = row_ingressi.targa;
                        modGUI.collegamento(row_ingressi.targa, 'gruppo5.moreInfoCar?id_Sessione=' || id_Sessione || '&nome=' ||
                            nome || '&ruolo=' || ruolo || '&idRiga=' || var_idVeicolo);
                    END;
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
		IF row_ingressi.entrataPrevista IS NOT NULL THEN
                    modGUI.elementoTabella(TO_CHAR(row_ingressi.entrataPrevista, 'DD-MON-RR', 'NLS_DATE_LANGUAGE = italian'));
                    modGUI.aCapo;
                    modGUI.elementoTabella(TO_CHAR(row_ingressi.entrataPrevista, 'HH24:MI:SS', 'NLS_DATE_LANGUAGE = italian'));
                ELSE
		    modGUI.elementoTabella('--');
                END IF;
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
                modGUI.inserisciLente('gruppo1.visualizzaBiglietto', id_Sessione, nome, ruolo, row_ingressi.idIngressoOrario);
            modGUI.chiudiElementoTabella;

            -- DETTAGLIO DELL'AREA UTILIZZATA --
            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo2.visualizzaArea', id_Sessione, nome, ruolo, row_ingressi.idarea);
            modGUI.chiudiElementoTabella;

            -- MULTE --
            modGUI.apriElementoTabella;
                IF row_ingressi.idMulta IS NULL AND ruolo != 'C' THEN
                    -- Se ad un ingresso non e' stata associata ancora una multa, espongo la procedura di inserimento
                    modGUI.inserisciPenna('gruppo1.inserisciCampiMulte', id_Sessione, nome, ruolo, row_ingressi.idingressoorario || 'O');
                ELSE
                    -- Se ad un ingresso e' stata gia' associata una multa, espongo la procedura di visualizzazione
                    modGUI.inserisciLente('gruppo1.dettaglioCampiMulte', id_Sessione, nome, ruolo, row_ingressi.idmulta);
                    modGUI.inserisciCestino('gruppo1.rimuoviMulteConferma', id_Sessione, nome, ruolo, row_ingressi.idmulta, '&tipoingresso=O');
		END IF;
            modGUI.chiudiElementoTabella;

            modGUI.chiudiRigaTabella;
        END LOOP;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
    END;

    IF var_noRecord THEN
        modGUI.apriDiv;
        modGUI.apriTabella;
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('ENTRATA PREVISTA');
                modGUI.intestazioneTabella('ORA ENTRATA');
                modGUI.intestazioneTabella('ORA USCITA');
                modGUI.intestazioneTabella('DETTAGLI INGRESSO');
                modGUI.intestazioneTabella('DETTAGLI AREA');
                modGUI.intestazioneTabella('MULTA');
            modGUI.chiudiRigaTabella;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
        modGUI.apriDiv(TRUE);
            modGUI.inserisciTesto('Non ci sono ingressi registrati per questo periodo e con questi filtri');
        modGUI.chiudiDiv;
    END IF;

    modGUI.chiudiPagina;
END visualizzaCronologia;

-- questa procedura visualizza i record della tabella areefasceorarie a seconda del filtro var_autorimessa
-- @param(autorimessa) = indirizzo dell'autorimessa (se non specificato considero tutte le autorimesse)
PROCEDURE visualizzaAreeFasce(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_autorimessa VARCHAR2) IS
    CURSOR cur_areeFasce IS
        SELECT autorimesse.idautorimessa, indirizzo, areeFasceOrarie.idArea, areeFasceOrarie.idFasciaoraria, nome, costo
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
                    END, oraInizio ASC, oraFine ASC;

    CURSOR cur_aree IS
        SELECT autorimesse.idAutorimessa, indirizzo, idArea
        FROM aree
        INNER JOIN autorimesse ON aree.idAutorimessa = autorimesse.idAutorimessa
        WHERE indirizzo LIKE (CASE WHEN var_autorimessa IS NULL THEN '%'
                                  ELSE var_autorimessa END)
        AND aree.idArea NOT IN (SELECT idArea
                                      FROM areeFasceOrarie);

    var_exists BOOLEAN := FALSE;
    var_idArea INTEGER;
BEGIN
    modGUI.apriPagina('HoC | Visualizza associazioni aree con fasce', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('VISUALIZZA ASSOCIAZIONI AREE CON FASCE');
    modGUI.chiudiIntestazione(2);

    modGUI.apriDiv;

    DECLARE
        primo INTEGER;
    BEGIN
        primo := -1;

        FOR row_areeFasce IN cur_areeFasce
        LOOP
            var_exists := TRUE;
	    
            IF primo != row_areeFasce.idArea THEN
                IF primo != -1 THEN
                    modGUI.chiudiTabella;
                    modGUI.apriDiv(TRUE);
                        modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'ASSOCIA NUOVA FASCIA', 'gruppo1.nuovaAreaFascia1',
                            '&idRiga=' || row_areeFasce.idArea);
                    modGUI.chiudiDiv;
                END IF;

                IF primo != row_areeFasce.idArea THEN
                    modGUI.apriIntestazione(3);
                            modGUI.inserisciTesto('AUTORIMESSA: ');
                            modGUI.collegamento(row_areefasce.indirizzo, 'gruppo2.visualizzaAutorimessa?id_Sessione=' || id_Sessione || 
                                '&nome=' || nome || '&ruolo=' || ruolo || '&idRiga=' || row_areeFasce.idAutorimessa);
                            modGUI.aCapo;
                            modGUI.inserisciTesto('AREA: ');
                            modGUI.collegamento(row_areefasce.idArea, 'gruppo2.visualizzaArea?id_Sessione=' || id_Sessione || '&nome=' ||
                                nome || '&ruolo=' || ruolo || '&idRiga=' || row_areeFasce.idArea);
                    modGUI.chiudiIntestazione(3);

                    primo := row_areeFasce.idArea;
                ELSE
                    modGUI.apriIntestazione(3);
                        modGUI.inserisciTesto('AREA: ');
                        modGUI.collegamento(row_areefasce.idArea, 'gruppo2.visualizzaArea?id_Sessione=' || id_Sessione || '&nome=' ||
                            nome || '&ruolo=' || ruolo || '&idRiga=' || row_areefasce.idArea);
                    modGUI.chiudiIntestazione(3);

                    primo := row_areeFasce.idArea;
                END IF;

                modGUI.apriTabella;
                modGUI.apriRigaTabella;
                    modGUI.intestazioneTabella('FASCIA');
                    modGUI.intestazioneTabella('DETTAGLI FASCIA');
                    modGUI.intestazioneTabella('COSTO');
                    IF ruolo = 'A' OR ruolo = 'R' OR ruolo = 'S' THEN
                        modGUI.intestazioneTabella('MODIFICA ASSOCIAZIONE');
                    END IF;
                modGUI.chiudiRigaTabella;
            END IF;
            modGUI.apriRigaTabella;

            modGUI.apriElementoTabella;
                modGUI.elementoTabella(row_areeFasce.nome);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo1.dettaglioFascia', id_Sessione, nome, ruolo, row_areeFasce.idFasciaoraria);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.elementoTabella(TO_CHAR(row_areeFasce.costo,'9990.09') || '&#8364/h');
            modGUI.chiudiElementoTabella;

            IF ruolo = 'A' OR ruolo = 'R' OR ruolo = 'S' THEN
            modGUI.apriElementoTabella;
                modGUI.inserisciPenna('gruppo1.nuovaAreaFascia2', id_Sessione, nome, ruolo, row_areeFasce.idArea,
                '&var_idFascia' || '=' || row_areeFasce.idFasciaOraria);
            modGUI.chiudiElementoTabella;
            END IF;
	    var_idArea := row_areeFasce.idArea;
            modGUI.chiudiRigaTabella;
        END LOOP;

    END;
    
    IF var_exists THEN
        modGUI.chiudiTabella;
        modGUI.apriDiv(TRUE);
            modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'ASSOCIA NUOVA FASCIA', 'gruppo1.nuovaAreaFascia1',
                '&idRiga=' || var_idArea);
        modGUI.chiudiDiv;
    END IF;
    modGUI.chiudiDiv;
    
    IF NOT var_exists THEN
        modGUI.apriDiv;
        modGUI.apriTabella;
            modGUI.apriRigaTabella;
                modGUI.intestazioneTabella('FASCIA');
                modGUI.intestazioneTabella('DETTAGLI FASCIA');
                modGUI.intestazioneTabella('COSTO');
                IF ruolo = 'A' OR ruolo = 'R' OR ruolo = 'S' THEN
                    modGUI.intestazioneTabella('MODIFICA ASSOCIAZIONE');
                END IF;
            modGUI.chiudiRigaTabella;
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;

        modGUI.apriDiv(TRUE);
            modGUI.inserisciTesto('Nessun dato da visualizzare');
        modGUI.chiudiDiv;
    END IF;
    
    modGUI.apriIntestazione(3);
        modGUI.inserisciTesto('AREE CHE NON SONO STATE ANCORA ASSOCIATE A NESSUNA FASCIA ORARIA');
    modGUI.chiudiIntestazione(3);

    modGUI.apriDiv;
    modGUI.apriTabella;

    modGUI.apriRigaTabella;
        modGUI.intestazioneTabella('AREA');
        modGUI.intestazioneTabella('DETTAGLI AREA');
        IF ruolo = 'A' OR ruolo = 'R' OR ruolo = 'S' THEN
            modGUI.intestazioneTabella('ASSOCIA FASCE');
        END IF;
        modGUI.intestazioneTabella('AUTORIMESSA');
        modGUI.intestazioneTabella('DETTAGLI AUTORIMESSA');
    modGUI.chiudiRigaTabella;
    var_exists := FALSE;

    FOR row_area IN cur_aree
    LOOP
        var_exists := TRUE;
        modGUI.apriRigaTabella;
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(row_area.idArea);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo2.visualizzaArea', id_Sessione, nome, ruolo, row_area.idArea);
            modGUI.chiudiElementoTabella;

            IF ruolo = 'A' OR ruolo = 'R' OR ruolo = 'S' THEN
            modGUI.apriElementoTabella;
                modGUI.inserisciPenna('gruppo1.nuovaAreaFascia1', id_Sessione, nome, ruolo, row_area.idArea);
            modGUI.chiudiElementoTabella;
            END IF;
            
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(row_area.indirizzo);
            modGUI.chiudiElementoTabella;

            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo2.visualizzaAutorimessa', id_Sessione, nome, ruolo, row_area.idAutorimessa);
            modGUI.chiudiElementoTabella;

        modGUI.chiudiRigaTabella;
    END LOOP;
    modGUI.chiudiTabella;

    modGUI.chiudiDiv;

    IF NOT var_exists THEN
        modGUI.apriDiv(TRUE);
            modGUI.inserisciTesto('Nessun dato da visualizzare');
        modGUI.chiudiDiv;
        modGUI.aCapo;
    END IF;

    modGUI.apriIntestazione(3);
	    modGUI.inserisciTesto('ALTRE OPERAZIONI');
    modGUI.chiudiIntestazione(3);
    modGUI.apriDiv(TRUE);
        modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'EFFETTUA UNA NUOVA RICERCA', 'gruppo1.areeFasce');
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
    modGUI.aCapo;
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('DETTAGLIO FASCIA');
    modGUI.chiudiIntestazione(2);

    SELECT nome, orainizio, orafine, giorno INTO var_nome, var_oraInizio, var_oraFine, var_giorno
    FROM fasceorarie
    WHERE idFasciaoraria = idRiga;

    modGUI.apriDiv;
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

    modGUI.chiudiPagina;
END dettaglioFascia;

PROCEDURE autorimessaTipoCarb(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Autorimessa con piu'' tipi di carburante', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('AUTORIMESSA CON PIU'' TIPI DI CARBURANTE');
    modGUI.chiudiIntestazione(2);

    modGUI.apriDiv;

    modGUI.apriForm('gruppo1.visualizzaAutorimessaTC');

    modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
    modGUI.inserisciInputHidden('nome', nome);
    modGUI.inserisciInputHidden('ruolo', ruolo);

    modGUI.inserisciInput('var_data', 'DATA', 'date', true);
    modGUI.apriSelect('var_tipo', 'TIPO CARBURANTE');
        modGUI.inserisciOpzioneSelect('N', 'NORMALE');
        modGUI.inserisciOpzioneSelect('GPL', 'GPL');
    modGUI.chiudiSelect;
    modGUI.inserisciBottoneReset('RESET');
    modGUI.inserisciBottoneForm('CERCA');

    modGUI.chiudiForm;
    modGUI.chiudiDiv;

    modGUI.chiudiPagina;
END autorimessaTipoCarb;

-- questa procedura implementa il calcolo della statistica numero 6:
-- Trovare il nome del parcheggio che ha il quantitativo massimo di veicoli parcheggiati con lo stesso tipo di carburante
-- @Param(var_data) = data (vengono considerati solo gli ingressi che attraversano questa data)
PROCEDURE visualizzaAutorimessaTC(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_data VARCHAR2, var_tipo VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Autorimessa con piu'' tipi di carburante', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('AUTORIMESSA CON PIU'' TIPI DI CARBURANTE');
    modGUI.chiudiIntestazione(2);

    modGUI.apriDiv;

    modGUI.apriTabella;

    modGUI.apriRigaTabella;
        modGUI.intestazioneTabella('AUTORIMESSA');
        modGUI.intestazioneTabella('DETTAGLI AUTORIMESSA');
        modGUI.intestazioneTabella('NUMERO');
    modGUI.chiudiRigaTabella;
    
    DECLARE
        var_idAutorimessa INTEGER;
        var_indirizzo VARCHAR2(100);
        var_numero INTEGER;
        
    BEGIN
        SELECT autorimesse.idAutorimessa, indirizzo, COUNT(alimentazione) AS numero INTO
            var_idAutorimessa, var_indirizzo, var_numero
        FROM
            (
                SELECT oraentrata, orauscita, idbox, alimentazione
                FROM ingressiorari
                INNER JOIN effettuaingressiorari ON ingressiorari.idingressoorario = effettuaingressiorari.idingressoorario
                INNER JOIN veicoli ON effettuaingressiorari.idveicolo = veicoli.idveicolo
                WHERE ingressiOrari.cancellato = 'F'
            UNION ALL
                SELECT oraentrata, orauscita, idbox, alimentazione
                FROM ingressiabbonamenti
                INNER JOIN effettuaingressiabbonamenti
                    ON ingressiabbonamenti.idingressoabbonamento = effettuaingressiabbonamenti.idingressoabbonamento
                INNER JOIN veicoli ON effettuaingressiabbonamenti.idveicolo = veicoli.idveicolo
                WHERE ingressiAbbonamenti.cancellato = 'F'
            ) tabApp
            INNER JOIN box ON tabApp.idBox = box.idbox
            INNER JOIN aree ON box.idarea  = aree.idarea
            INNER JOIN autorimesse ON aree.idautorimessa = autorimesse.idautorimessa
            WHERE
                -- considero gli ingressi che sono avvenuti e terminati
                oraentrata IS NOT NULL AND orauscita IS NOT NULL AND
                (TO_TIMESTAMP(TO_CHAR(TO_TIMESTAMP(var_data, 'YYYY-MM-DD'), 'DD-MON-RR'), 'DD-MON-RR') BETWEEN
                    TO_TIMESTAMP(TO_CHAR(oraentrata, 'DD-MON-RR') || ' 0:0:0', 'DD-MON-RR HH24:MI:SS')  AND
                    TO_TIMESTAMP(TO_CHAR(orauscita, 'DD-MON-RR') || ' 23:59:59', 'DD-MON-RR HH24:MI:SS')) AND
                alimentazione = var_tipo
            GROUP BY autorimesse.idautorimessa, autorimesse.indirizzo, alimentazione
            ORDER BY numero DESC, alimentazione ASC
            FETCH FIRST 1 ROW ONLY;
            
        modGUI.apriRigaTabella;
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(var_indirizzo);
            modGUI.chiudiElementoTabella;
        
            modGUI.apriElementoTabella;
                modGUI.inserisciLente('gruppo2.visualizzaAutorimessa', id_Sessione, nome, ruolo, var_idAutorimessa);
            modGUI.chiudiElementoTabella;
        
            modGUI.apriElementoTabella;
                modGUI.elementoTabella(var_numero);
            modGUI.chiudiElementoTabella;
        modGUI.chiudiRigaTabella;
        
        modGUI.chiudiTabella;
        modGUI.chiudiDiv;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                modGUI.chiudiTabella;
                modGUI.chiudiDiv;
                modGUI.apriDiv(TRUE);
                    modGUI.inserisciTesto('Nessun dato da visualizzare');
                modGUI.chiudiDiv;
                modGUI.aCapo;
    END;

    modGUI.apriIntestazione(3);
	    modGUI.inserisciTesto('ALTRE OPERAZIONI');
    modGUI.chiudiIntestazione(3);
    modGUI.apriDiv(TRUE);
        modGUI.inserisciBottone(id_Sessione, nome, ruolo, 'INDIETRO', 'gruppo1.autorimessaTipoCarb');
    modGUI.chiudiDiv;
    
    modGUI.chiudiPagina;

END visualizzaAutorimessaTC;

-- questa procedura implementa il form nel caso in cui si voglia associare una fascia ad un area (già passata come input)
-- oppure se la fascia era già stata associata aggiornare il campo costo di un record della tabella areefasceorarie
-- @Param(idRiga) = id della fascia oraria
PROCEDURE nuovaAreaFascia1(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2) IS
    CURSOR cur_fasce IS
        SELECT idfasciaoraria, nome
        FROM fasceorarie
        ORDER BY CASE
                    WHEN giorno = 'LUN' THEN 1
                    WHEN giorno = 'MAR' THEN 2
                    WHEN giorno = 'MER' THEN 3
                    WHEN giorno = 'GIO' THEN 4
                    WHEN giorno = 'VEN' THEN 5
                    WHEN giorno = 'SAB' THEN 6
                    WHEN giorno = 'DOM' THEN 7
                    END, oraInizio, oraFine;
        
        row_fascia cur_fasce%ROWTYPE;
BEGIN
    modGUI.apriPagina('HoC | Inserimento/modifica associazione area a fascia', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('INSERIMENTO/MODIFICA ASSOCIAZIONE AREA A FASCIA');
    modGUI.chiudiIntestazione(2);

    OPEN cur_fasce;
    FETCH cur_fasce INTO row_fascia;
    
    IF cur_fasce%ROWCOUNT = 0 THEN
        modGUI.apriIntestazione(3);
            modGUI.inserisciTesto('Non ci sono ancora fasce orarie');
        modGUI.chiudiIntestazione(3);
        modGUI.chiudiPagina;
        CLOSE cur_fasce;
    END IF;
    
    modGUI.apriIntestazione(3);
        modGUI.inserisciTesto('AREA: ');
        modGUI.collegamento(idRiga, 'gruppo2.visualizzaArea?id_Sessione=' || id_Sessione || '&nome=' || nome || '&ruolo=' ||
            ruolo || '&idRiga=' || idRiga);
    modGUI.chiudiIntestazione(3);
    
    modGUI.apriDiv;
        modGUI.apriForm('gruppo1.modAreaFasciaRis');

        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        modGUI.inserisciInputHidden('var_idArea', idRiga);

        modGUI.apriSelect('var_idFascia', 'FASCIA');
        LOOP
            modGUI.inserisciOpzioneSelect(row_fascia.idfasciaoraria, row_fascia.nome);
            FETCH cur_fasce INTO row_fascia;
            EXIT WHEN cur_fasce%NOTFOUND;
        END LOOP;
        modGUI.chiudiSelect;
        CLOSE cur_fasce;

        modGUI.inserisciInput('var_costo', 'Costo', 'number', true);
        modGUI.inserisciRadioButton('INSERIMENTO', 'var_tipo', '0', true);
        modGUI.inserisciRadioButton('MODIFICA', 'var_tipo', '1', false);
        modGUI.inserisciBottoneReset;
        modGUI.inserisciBottoneForm('SUBMIT');
        modGUI.chiudiForm;

    modGUI.chiudiDiv;

    modGUI.chiudiPagina;
END nuovaAreaFascia1;

-- questa procedura implementa il form nel caso in cui si voglia semplicemente modificare il costo di un record della
-- tabella areefasceorarie
-- @Param(var_idFascia) = id della fascia oraria
-- @Param(costo) = costo da inserire
PROCEDURE nuovaAreaFascia2(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, idRiga VARCHAR2, var_idFascia VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Modifica associazione area a fascia', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('MODIFICA ASSOCIAZIONE AREA A FASCIA');
    modGUI.chiudiIntestazione(2);

    modGUI.apriIntestazione(3);
        modGUI.inserisciTesto('AREA: ');
        modGUI.collegamento(idRiga, 'gruppo2.visualizzaArea?id_Sessione=' || id_Sessione || '&nome=' || nome || '&ruolo=' ||
            ruolo || '&idRiga=' || idRiga);
        modGUI.aCapo;
        modGUI.inserisciTesto('FASCIA: ');
        modGUI.collegamento(var_idFascia, 'gruppo1.dettaglioFascia?id_Sessione=' || id_Sessione || '&nome=' || nome || '&ruolo=' ||
            ruolo || '&idRiga=' || var_idFascia);
    modGUI.chiudiIntestazione(3);
    
    modGUI.apriDiv;
        modGUI.apriForm('gruppo1.modAreaFasciaRis');

        modGUI.inserisciInputHidden('id_Sessione', id_Sessione);
        modGUI.inserisciInputHidden('nome', nome);
        modGUI.inserisciInputHidden('ruolo', ruolo);
        modGUI.inserisciInputHidden('var_idArea', idRiga);
        modGUI.inserisciInputHidden('var_idFascia', var_idFascia);

        modGUI.inserisciInput('var_costo', 'Costo', 'number', true);
          
        modGUI.inserisciInputHidden('var_tipo', '1');
        modGUI.inserisciBottoneReset;
        modGUI.inserisciBottoneForm('SUBMIT');
        modGUI.chiudiForm;

    modGUI.chiudiDiv;

    modGUI.chiudiPagina;
END nuovaAreaFascia2;

/*
    Questa procedura inserisce un nuovo record di tipo <idArea, idFasciaOraria, costo> alla tabella AreeFasceorarie se non è
    già presente, altrimenti modifica il campo costo
    @Param(var_idArea) = id dell'area
    @Param(var_idFascia) = id della fascia oraria
    @Param(costo) = costo da inserire
*/
PROCEDURE modAreaFasciaRis(id_Sessione VARCHAR2, nome VARCHAR2, ruolo VARCHAR2, var_idArea VARCHAR2, var_idFascia VARCHAR2,
    var_costo VARCHAR2, var_tipo VARCHAR2) IS
BEGIN
    modGUI.apriPagina('HoC | Inserimento/Modifica associazione area a fascia', id_Sessione, nome, ruolo);
    modGUI.aCapo;
    modGUI.apriIntestazione(2);
        modGUI.inserisciTesto('INSERIMENTO/MODIFICA ASSOCIAZIONE AREA A FASCIA');
    modGUI.chiudiIntestazione(2);

    modGUI.apriDiv;
      
    IF TO_NUMBER(var_costo) <= 0 THEN
        modGUI.esitoOperazione('KO', 'Costo non valido');
        modGUI.chiudiDiv;
        modGUI.chiudiPagina;
        RETURN;
    END IF;
    
    DECLARE
        var_conta INTEGER;
    BEGIN
        SELECT idarea INTO var_conta
        FROM areefasceorarie
        WHERE idarea = var_idArea AND idFasciaoraria = var_idFascia;
            
        IF var_tipo = '0' THEN  
            modGUI.esitoOperazione('KO', 'Questa associazione esiste gia''');
        ELSIF var_tipo = '1' THEN
            UPDATE areefasceorarie
            SET costo = TO_NUMBER(var_costo)
            WHERE idArea = TO_NUMBER(var_idArea) AND idFasciaOraria = TO_NUMBER(var_idFascia);
            COMMIT;	
            modGUI.esitoOperazione('OK', 'Modifica avvenuta con successo');
        END IF;

        EXCEPTION
            -- ancora l'area non era stata associata a questa fascia
            WHEN NO_DATA_FOUND THEN
                INSERT INTO areefasceorarie
                VALUES (var_idArea, var_idfascia, var_costo);
    		COMMIT;
                modGUI.esitoOperazione('OK', 'Inserimento avvenuto con successo');
            WHEN OTHERS THEN
                modGUI.esitoOperazione('KO', 'Ci sono ingressi ancora attivi per quest''area');
        END;
    modGUI.chiudiDiv;
    modGUI.chiudiPagina;
END modAreaFasciaRis;

END ALESSANDRO;