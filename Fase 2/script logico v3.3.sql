-- GRUPPO LOGICO --
-- Puccia Alessandro --
-- Vigiani Andrea --

-- Versione 3.3 --
-- 29 Novembre 2019 --

-- -----------------------------------------------------
-- Table Abbonamenti
-- -----------------------------------------------------
DROP TABLE Abbonamenti CASCADE CONSTRAINT;

DROP SEQUENCE AbbonamentiSeq;

CREATE SEQUENCE AbbonamentiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Abbonamenti 
(
  idAbbonamento INTEGER NOT NULL,
  DataInizio DATE NOT NULL,
  DataFine DATE NOT NULL,
  CostoEffettivo NUMBER(6, 2) NOT NULL,
  PagamentiAbbonamenti NUMBER(6, 2) DEFAULT 0 NOT NULL,	
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idCliente INTEGER NOT NULL,
  idTipoAbbonamento INTEGER NOT NULL,

  PRIMARY KEY (idAbbonamento),
  CONSTRAINT abbonamenti_datafine_ck CHECK(DataFine > DataInizio), 
  CONSTRAINT abbonamenti_costoeffettivo_ck CHECK(CostoEffettivo > 0),
  CONSTRAINT abbonamenti_pagamentiabbonamenti_ck CHECK(PagamentiAbbonamenti >= 0),
  CONSTRAINT abbonamenti_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);


-- -----------------------------------------------------
-- Table AbbonamentiClienti
-- -----------------------------------------------------
DROP TABLE AbbonamentiClienti CASCADE CONSTRAINT;

CREATE TABLE AbbonamentiClienti 
(
  idAbbonamento INTEGER NOT NULL,
  idCliente INTEGER NOT NULL,

  PRIMARY KEY (idCliente, idAbbonamento)
);



-- -----------------------------------------------------
-- Table AbbonamentiVeicoli
-- -----------------------------------------------------
DROP TABLE AbbonamentiVeicoli CASCADE CONSTRAINT;

CREATE TABLE AbbonamentiVeicoli 
(
  idAbbonamento INTEGER NOT NULL,
  idVeicolo INTEGER NOT NULL,

  PRIMARY KEY (idAbbonamento, idVeicolo)
);


-- -----------------------------------------------------
-- Table Annotazioni
-- -----------------------------------------------------
DROP TABLE Annotazioni CASCADE CONSTRAINT;

DROP SEQUENCE AnnotazioniSeq;

CREATE SEQUENCE AnnotazioniSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Annotazioni
(
  idAnnotazione INTEGER NOT NULL,
  Data DATE NOT NULL,
  Motivo VARCHAR(2000) NOT NULL,
  Merito_Demerito CHAR(3) NOT NULL,
  idDipendente INTEGER NOT NULL,

  PRIMARY KEY (idAnnotazione),
  CONSTRAINT annotazioni_merito_demerito_ck CHECK(Merito_Demerito IN ('POS', 'NEG'))
);


-- -----------------------------------------------------
-- Table Aree
-- -----------------------------------------------------
DROP TABLE Aree CASCADE CONSTRAINT;

DROP SEQUENCE AreeSeq;

CREATE SEQUENCE AreeSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Aree 
(
  idArea INTEGER NOT NULL,
  PostiTotali INTEGER NOT NULL,
  PostiLiberi INTEGER NOT NULL,
  Stato CHAR(3) NOT NULL,
  Gas CHAR(1) NOT NULL,
  LunghezzaMax INT NOT NULL,
  LarghezzaMax INT NOT NULL,
  AltezzaMax INT NOT NULL,
  PesoMax INT NOT NULL,
  CostoAbbonamento NUMBER(6, 2) NOT NULL,
  idAutorimessa INTEGER NOT NULL,

  PRIMARY KEY (idArea),
  CONSTRAINT aree_postitotali_ck CHECK(PostiTotali>0),
  CONSTRAINT aree_postiliberi_ck CHECK(PostiLiberi>=0),
  CONSTRAINT aree_stato_ck CHECK(Stato IN ('FUN', 'MAN', 'CHI')),
  CONSTRAINT aree_gas_ck CHECK(Gas IN ('T', 'F')),
  CONSTRAINT aree_lunghezzamax_ck CHECK(LunghezzaMax>0),
  CONSTRAINT aree_larghezzamax_ck CHECK(LarghezzaMax>0),
  CONSTRAINT aree_altezzamax_ck CHECK(AltezzaMax>0),
  CONSTRAINT aree_pesomax_ck CHECK(PesoMax>0),
  CONSTRAINT aree_costoabbonamento_ck CHECK(CostoAbbonamento>0)
);



-- -----------------------------------------------------
-- Table AreeFasceorarie
-- -----------------------------------------------------
DROP TABLE AreeFasceorarie CASCADE CONSTRAINT;

CREATE TABLE AreeFasceorarie
(
  idArea INT NOT NULL,
  idFasciaOraria INT NOT NULL,
  Costo NUMBER(6, 2) NOT NULL,

  PRIMARY KEY (idArea, idFasciaOraria),
  CONSTRAINT areefasceorarie_costo_ck CHECK(Costo>0)
);



-- -----------------------------------------------------
-- Table Assicurazioni
-- -----------------------------------------------------
DROP TABLE Assicurazioni CASCADE CONSTRAINT;

DROP SEQUENCE AssicurazioniSeq;

CREATE SEQUENCE AssicurazioniSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Assicurazioni
(
  idAssicurazione INTEGER NOT NULL,
  Descrizione VARCHAR(2000) NOT NULL,
  CostoMensile NUMBER(6, 2)  NOT NULL,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idAbbonamento INT NOT NULL,

  PRIMARY KEY (idAssicurazione),
  CONSTRAINT assicurazioni_costomensile_ck CHECK(CostoMensile>0),
  CONSTRAINT assicurazioni_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table Autorimesse
-- -----------------------------------------------------
DROP TABLE Autorimesse CASCADE CONSTRAINT;

DROP SEQUENCE AutorimesseSeq;

CREATE SEQUENCE AutorimesseSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Autorimesse
(
  idAutorimessa INTEGER NOT NULL,
  Indirizzo VARCHAR(100) NOT NULL UNIQUE,
  Telefono CHAR(10) NOT NULL,
  Coordinate VARCHAR(45) NOT NULL,
  idSede INTEGER NOT NULL,

  PRIMARY KEY (idAutorimessa)
);



-- -----------------------------------------------------
-- Table BlackList
-- -----------------------------------------------------
DROP TABLE Blacklist CASCADE CONSTRAINT;

DROP SEQUENCE BlacklistSeq;

CREATE SEQUENCE BlacklistSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE BlackList 
(
  idBlackList INTEGER NOT NULL,
  DataInserimento DATE NOT NULL,
  CausaInserimento VARCHAR(2000) NOT NULL,
  Durata DATE NULL,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idCliente INTEGER NOT NULL,

  PRIMARY KEY (idBlackList),
  CONSTRAINT blacklist_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table Box
-- -----------------------------------------------------
DROP TABLE Box CASCADE CONSTRAINT;

DROP SEQUENCE BoxSeq;

CREATE SEQUENCE BoxSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Box 
(
  idBox INTEGER NOT NULL,
  Numero INTEGER NOT NULL,
  Piano INTEGER NOT NULL,
  NumeroColonna INTEGER NOT NULL,
  Occupato CHAR(1) NOT NULL,
  Riservato CHAR(1) NOT NULL,
  idArea INTEGER NOT NULL,
  idAbbonamento INTEGER NULL,
  PRIMARY KEY (idBox),

  CONSTRAINT box_numero_ck CHECK(Numero>0),
  CONSTRAINT box_numerocolonna_ck CHECK(NumeroColonna>0),
  CONSTRAINT box_occupato_ck CHECK(Occupato IN ('T', 'F')),
  CONSTRAINT box_riservato_ck CHECK(Riservato IN ('T', 'F'))
);


-- -----------------------------------------------------
-- Table Clienti
-- -----------------------------------------------------
DROP TABLE Clienti CASCADE CONSTRAINT;

DROP SEQUENCE ClientiSeq;

CREATE SEQUENCE ClientiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Clienti 
(
  idCliente INTEGER NOT NULL,
  NumeroPatente CHAR(10) NOT NULL UNIQUE,
  DataScadenzaPatente DATE NOT NULL,
  CartaDiCredito CHAR(16) NOT NULL UNIQUE,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idPersona INTEGER NOT NULL,

  PRIMARY KEY (idCliente),
  CONSTRAINT clienti_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table Contratti
-- -----------------------------------------------------
DROP TABLE Contratti CASCADE CONSTRAINT;

DROP SEQUENCE ContrattiSeq;

CREATE SEQUENCE ContrattiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Contratti
(
  idContratto INTEGER NOT NULL,
  DataSottoscrizione DATE NOT NULL,
  DataTermine DATE NULL,
  DataLicenziamento DATE NULL,
  MotivoLicenziamento VARCHAR(2000) NULL,
  idDipendente INTEGER NOT NULL,
  idTipoContratto INTEGER NOT NULL,

  PRIMARY KEY (idContratto),
  CONSTRAINT contratti_datatermine_ck CHECK(DataTermine > DataSottoscrizione),
  CONSTRAINT contratti_datalicenziamento_ck CHECK(DataLicenziamento > DataSottoscrizione)
);



-- -----------------------------------------------------
-- Table Dipendenti
-- -----------------------------------------------------
DROP TABLE Dipendenti CASCADE CONSTRAINT;

DROP SEQUENCE DipendentiSeq;

CREATE SEQUENCE DipendentiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Dipendenti 
(
  idDipendente INTEGER NOT NULL,
  TipoDipendente CHAR(1) NOT NULL,
  Iban CHAR(27) NOT NULL,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idPersona INTEGER NOT NULL,
  idAutorimessa INTEGER NULL,

  PRIMARY KEY (idDipendente),
  CONSTRAINT dipendenti_tipodipendente_ck CHECK(TipoDipendente IN ('A', 'R', 'S', 'O')),
  CONSTRAINT dipendenti_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table EffettuaIngressiAbbonamenti
-- -----------------------------------------------------
DROP TABLE EffettuaIngressiAbbonamenti CASCADE CONSTRAINT;

CREATE TABLE EffettuaIngressiAbbonamenti
(
  idVeicolo INTEGER NOT NULL,
  idCliente INTEGER NOT NULL,
  idIngressoAbbonamento INTEGER NOT NULL,

  PRIMARY KEY (idVeicolo, idCliente, idIngressoAbbonamento)
);



-- -----------------------------------------------------
-- Table EffettuaIngressiOrari
-- -----------------------------------------------------
DROP TABLE EffettuaIngressiOrari CASCADE CONSTRAINT;

CREATE TABLE EffettuaIngressiOrari
(
  idVeicolo INTEGER NOT NULL,
  idCliente INTEGER NOT NULL,
  idIngressoOrario INTEGER NOT NULL,

  PRIMARY KEY (idVeicolo, idCliente, idIngressoOrario)
);



-- -----------------------------------------------------
-- Table FasceOrarie
-- -----------------------------------------------------
DROP TABLE FasceOrarie CASCADE CONSTRAINT;

DROP SEQUENCE FasceOrarieSeq;

CREATE SEQUENCE FasceOrarieSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE FasceOrarie 
(
  idFasciaOraria INTEGER NOT NULL,
  Nome VARCHAR(45) NOT NULL,
  OraInizio TIMESTAMP NOT NULL,
  OraFine TIMESTAMP NOT NULL,
  Giorno CHAR(3) NOT NULL,
  
  PRIMARY KEY (idFasciaOraria),
  CONSTRAINT fasceorarie_orafine_ck CHECK(OraFine > OraInizio),
  CONSTRAINT fasceorarie_giorno_ck CHECK(Giorno IN ('LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'))
);



-- -----------------------------------------------------
-- Table IngressiAbbonamenti
-- -----------------------------------------------------
DROP TABLE IngressiAbbonamenti CASCADE CONSTRAINT;

DROP SEQUENCE IngressiAbbonamentiSeq;

CREATE SEQUENCE IngressiAbbonamentiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE IngressiAbbonamenti
(
  idIngressoAbbonamento INTEGER NOT NULL,
  OraEntrata TIMESTAMP NOT NULL,
  OraUscita TIMESTAMP NULL,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idAbbonamento INTEGER NOT NULL,
  idBox INTEGER NOT NULL,
  idMulta INTEGER NULL,

  PRIMARY KEY (idIngressoAbbonamento),
  CONSTRAINT ingressiabbonamenti_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table IngressiOrari
-- -----------------------------------------------------
DROP TABLE IngressiOrari CASCADE CONSTRAINT;

DROP SEQUENCE IngressiOrariSeq;

CREATE SEQUENCE IngressiOrariSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE IngressiOrari
(
  idIngressoOrario INTEGER NOT NULL,
  EntrataPrevista TIMESTAMP NULL,
  OraEntrata TIMESTAMP NULL,
  OraUscita TIMESTAMP NULL,
  Costo NUMBER(6, 2) NULL,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,
  idBox INTEGER NOT NULL,
  idMulta INTEGER NULL,

  PRIMARY KEY (idIngressoOrario),
  CONSTRAINT ingressi_costo_ck CHECK(Costo>0),
  CONSTRAINT ingressiorari_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table Multe
-- -----------------------------------------------------
DROP TABLE Multe CASCADE CONSTRAINT;

DROP SEQUENCE MulteSeq;

CREATE SEQUENCE MulteSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Multe
(
  idMulta INTEGER NOT NULL,
  DataAssegnazione TIMESTAMP NOT NULL,
  Importo NUMBER(6, 2) NOT NULL,
  Causa VARCHAR(2000) NOT NULL,
  Pagata TIMESTAMP NULL,
  Cancellato CHAR(1) DEFAULT 'F' NOT NULL,

  PRIMARY KEY (idMulta),
  CONSTRAINT multe_importo_ck CHECK(Importo>0),
  CONSTRAINT multe_cancellato_ck CHECK(Cancellato IN ('T', 'F'))
);



-- -----------------------------------------------------
-- Table Pagamenti
-- -----------------------------------------------------
DROP TABLE Pagamenti CASCADE CONSTRAINT;

DROP SEQUENCE PagamentiSeq;

CREATE SEQUENCE PagamentiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Pagamenti 
(
  idPagamento INTEGER NOT NULL,
  Data DATE NOT NULL,
  StipendioPagato NUMBER(6, 2) NOT NULL,
  idDipendente INTEGER NOT NULL,

  PRIMARY KEY (idPagamento),
  CONSTRAINT pagamenti_stipendiopagato_ck CHECK(StipendioPagato > 0)
);



-- -----------------------------------------------------
-- Table Persone
-- -----------------------------------------------------
DROP TABLE Persone CASCADE CONSTRAINT;

DROP SEQUENCE PersoneSeq;

CREATE SEQUENCE PersoneSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Persone
(
  idPersona INTEGER NOT NULL,
  CodiceFiscale CHAR(16) NOT NULL UNIQUE,
  Cognome VARCHAR(45) NOT NULL,
  Nome VARCHAR(45) NOT NULL,
  Indirizzo VARCHAR(100) NOT NULL,
  Sesso CHAR(1) NOT NULL,
  Email VARCHAR(45) NOT NULL,
  Telefono VARCHAR(10) NOT NULL,
  DataNascita DATE NOT NULL,

  PRIMARY KEY (idPersona),
  CONSTRAINT persone_sesso_ck CHECK(Sesso IN ('M', 'F', 'A')),
  CONSTRAINT persone_email_ck CHECK(Email LIKE ('%@%.%'))
);



-- -----------------------------------------------------
-- Table RegistroPresenze
-- -----------------------------------------------------
DROP TABLE RegistroPresenze CASCADE CONSTRAINT;

DROP SEQUENCE RegistroPresenzeSeq;

CREATE SEQUENCE RegistroPresenzeSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE RegistroPresenze 
(
  idRegistroPresenza INTEGER NOT NULL,
  OraEntrata TIMESTAMP NOT NULL,
  OraUscita TIMESTAMP NULL,
  Note VARCHAR(2000) NULL,
  idDipendente INTEGER NOT NULL,

  PRIMARY KEY (idRegistroPresenza)
);



-- -----------------------------------------------------
-- Table Sedi
-- -----------------------------------------------------
DROP TABLE Sedi CASCADE CONSTRAINT;

DROP SEQUENCE SediSeq;

CREATE SEQUENCE SediSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Sedi
(
  idSede INTEGER NOT NULL,
  Indirizzo VARCHAR (100) NOT NULL UNIQUE,
  Telefono CHAR (10) NOT NULL,
  Coordinate VARCHAR (45) NOT NULL,
  idDipendente INTEGER NOT NULL,

  PRIMARY KEY (idSede)
);



-- -----------------------------------------------------
-- Table TipiAbbonamenti
-- -----------------------------------------------------
DROP TABLE TipiAbbonamenti CASCADE CONSTRAINT;

DROP SEQUENCE TipiAbbonamentiSeq;

CREATE SEQUENCE TipiAbbonamentiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE TipiAbbonamenti 
(
  idTipoAbbonamento INTEGER NOT NULL,
  MaxVeicoli INTEGER NOT NULL,
  MaxClienti INTEGER NOT NULL,
  MaxAutorimesse INTEGER NOT NULL,
  Durata INT NOT NULL,
  Costo NUMBER(6, 2) NOT NULL,
  TipoAbbonamento VARCHAR(45) UNIQUE NOT NULL,
  OraInizio INTEGER NOT NULL,
  OraFine INTEGER NOT NULL,

  PRIMARY KEY (idTipoAbbonamento),
  CONSTRAINT tipiabbonamenti_maxveicoli_ck CHECK(MaxVeicoli>0),
  CONSTRAINT tipiabbonamenti_maxclienti_ck CHECK(MaxClienti>0),
  CONSTRAINT tipiabbonamenti_maxautorimesse_ck CHECK(MaxAutorimesse>0),
  CONSTRAINT tipiabbonamenti_durata_ck CHECK(Durata>0),
  CONSTRAINT tipiabbonamenti_costo_ck CHECK(Costo>0),
  CONSTRAINT tipiabbonamenti_orainizio_ck check(oraInizio >= 0 and oraInizio <= 23),
  CONSTRAINT tipiabbonamenti_orafine_ck check(oraFine >= 0 and oraFine <= 23)
 );



-- -----------------------------------------------------
-- Table TipiContratti
-- -----------------------------------------------------
DROP TABLE TipiContratti CASCADE CONSTRAINT;

DROP SEQUENCE TipiContrattiSeq;

CREATE SEQUENCE TipiContrattiSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE TipiContratti
(
  idTipoContratto INTEGER NOT NULL,
  MinimoOreGiornaliere INTEGER NOT NULL,
  MinimoOreSettimanali INTEGER NOT NULL,
  MinimoOreMensili INTEGER NOT NULL ,
  MinimaRetribuzione NUMBER(6, 2) NOT NULL,
  PRIMARY KEY (idTipoContratto),

  CONSTRAINT tipicontratti_minimooregiornaliere_ck CHECK(MinimoOreGiornaliere>0),
  CONSTRAINT tipicontratti_minimooresettimanali_ck CHECK(MinimoOreSettimanali>0),
  CONSTRAINT tipicontratti_minimooremensili_ck CHECK(MinimoOreMensili>0),
  CONSTRAINT tipicontratti_minimaretribuzione_ck CHECK(MinimaRetribuzione>0)
);



-- -----------------------------------------------------
-- Table Turni
-- -----------------------------------------------------
DROP TABLE Turni CASCADE CONSTRAINT;

DROP SEQUENCE TurniSeq;

CREATE SEQUENCE TurniSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Turni
(
  idTurno INTEGER NOT NULL,
  OrarioInizio TIMESTAMP NOT NULL,
  OrarioFine TIMESTAMP NOT NULL,
  Giorno CHAR(3) NOT NULL,
  InizioValidita DATE NOT NULL,
  FineValidita DATE NULL,
  idDipendente INTEGER NOT NULL,

  PRIMARY KEY (idTurno),
  CONSTRAINT turni_finevalidita_ck CHECK(FineValidita > InizioValidita),
  CONSTRAINT turni_giorno_ck CHECK(Giorno IN ('LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'))
);



-- -----------------------------------------------------
-- Table Veicoli
-- -----------------------------------------------------
DROP TABLE Veicoli CASCADE CONSTRAINT;

DROP SEQUENCE VeicoliSeq;

CREATE SEQUENCE VeicoliSeq
START WITH 1
INCREMENT BY 1
NOCYCLE;

CREATE TABLE Veicoli 
(
  idVeicolo INTEGER NOT NULL,
  Targa CHAR(7) NOT NULL UNIQUE,
  Produttore VARCHAR(45) NOT NULL,
  Modello VARCHAR(45) NOT NULL,
  Colore VARCHAR(45) NOT NULL,
  Altezza INTEGER NOT NULL,
  Larghezza INTEGER NOT NULL,
  Lunghezza INTEGER NOT NULL,
  Peso INTEGER NOT NULL,
  Alimentazione VARCHAR(3) NOT NULL,
  Annotazione VARCHAR(2000) NULL,

  PRIMARY KEY (idVeicolo),
  CONSTRAINT veicoli_altezza_ck CHECK(Altezza>0),
  CONSTRAINT veicoli_larghezza_ck CHECK(Larghezza>0),
  CONSTRAINT veicoli_lunghezza_ck CHECK(Lunghezza>0),
  CONSTRAINT veicoli_peso_ck CHECK(Peso>0),
  CONSTRAINT veicoli_alimentazione_ck CHECK(Alimentazione IN ('N', 'GPL'))
);



-- -----------------------------------------------------
-- Table VeicoliClienti
-- -----------------------------------------------------
DROP TABLE VeicoliClienti CASCADE CONSTRAINT;

CREATE TABLE VeicoliClienti 
(
  idVeicolo INTEGER NOT NULL,
  idCliente INTEGER NOT NULL,

  PRIMARY KEY (idCliente, idVeicolo)
);



-- default NO ACTION --

ALTER TABLE Abbonamenti
ADD FOREIGN KEY (idCliente) REFERENCES Clienti(idCliente);

ALTER TABLE Abbonamenti
ADD FOREIGN KEY (idTipoAbbonamento) REFERENCES TipiAbbonamenti(idTipoAbbonamento);

ALTER TABLE AbbonamentiClienti
ADD FOREIGN KEY (idAbbonamento) REFERENCES Abbonamenti(idAbbonamento);

ALTER TABLE AbbonamentiClienti
ADD FOREIGN KEY (idCliente) REFERENCES Clienti(idCliente);

ALTER TABLE AbbonamentiVeicoli
ADD FOREIGN KEY (idAbbonamento) REFERENCES Abbonamenti(idAbbonamento);

ALTER TABLE AbbonamentiVeicoli
ADD FOREIGN KEY (idVeicolo) REFERENCES Veicoli(idVeicolo);

ALTER TABLE Annotazioni
ADD FOREIGN KEY (idDipendente) REFERENCES Dipendenti(idDipendente);

ALTER TABLE Aree
ADD FOREIGN KEY (idAutorimessa) REFERENCES Autorimesse(idAutorimessa);

ALTER TABLE AreeFasceOrarie
ADD FOREIGN KEY (idArea) REFERENCES Aree(idArea);

ALTER TABLE AreeFasceOrarie
ADD FOREIGN KEY (idFasciaOraria) REFERENCES FasceOrarie(idFasciaOraria);

ALTER TABLE Assicurazioni
ADD FOREIGN KEY (idAbbonamento) REFERENCES Abbonamenti(idAbbonamento);

ALTER TABLE Autorimesse 
ADD FOREIGN KEY (idSede) REFERENCES Sedi(idSede);

ALTER TABLE Blacklist
ADD FOREIGN KEY (idCliente) REFERENCES Clienti(idCliente);

ALTER TABLE Box
ADD FOREIGN KEY (idArea) REFERENCES Aree(idArea);

ALTER TABLE Box
ADD FOREIGN KEY (idAbbonamento) REFERENCES Abbonamenti(idAbbonamento);

ALTER TABLE Clienti
ADD FOREIGN KEY (idPersona) REFERENCES Persone(idPersona);

ALTER TABLE Contratti
ADD FOREIGN KEY (idDipendente) REFERENCES Dipendenti(idDipendente);

ALTER TABLE Contratti
ADD FOREIGN KEY (idTipoContratto) REFERENCES TipiContratti(idTipoContratto);

ALTER TABLE Dipendenti 
ADD FOREIGN KEY (idPersona) REFERENCES Persone(idPersona);

ALTER TABLE Dipendenti 
ADD FOREIGN KEY (idAutorimessa) REFERENCES Autorimesse(idAutorimessa);

ALTER TABLE EffettuaIngressiAbbonamenti
ADD FOREIGN KEY (idVeicolo) REFERENCES Veicoli(idVeicolo);

ALTER TABLE EffettuaIngressiAbbonamenti
ADD FOREIGN KEY (idCliente) REFERENCES Clienti(idCliente);

ALTER TABLE EffettuaIngressiAbbonamenti
ADD FOREIGN KEY (idIngressoAbbonamento) REFERENCES IngressiAbbonamenti(idIngressoAbbonamento);

ALTER TABLE EffettuaIngressiOrari
ADD FOREIGN KEY (idVeicolo) REFERENCES Veicoli(idVeicolo);

ALTER TABLE EffettuaIngressiOrari
ADD FOREIGN KEY (idCliente) REFERENCES Clienti(idCliente);

ALTER TABLE EffettuaIngressiOrari
ADD FOREIGN KEY (idIngressoOrario) REFERENCES IngressiOrari(idIngressoOrario);

ALTER TABLE IngressiAbbonamenti
ADD FOREIGN KEY (idAbbonamento) REFERENCES Abbonamenti(idAbbonamento);

ALTER TABLE IngressiAbbonamenti
ADD FOREIGN KEY (idBox) REFERENCES Box(idBox);

ALTER TABLE IngressiAbbonamenti
ADD FOREIGN KEY (idMulta) REFERENCES Multe(idMulta);

ALTER TABLE IngressiOrari
ADD FOREIGN KEY (idBox) REFERENCES Box(idBox);

ALTER TABLE IngressiOrari
ADD FOREIGN KEY (idMulta) REFERENCES Multe(idMulta);

ALTER TABLE Pagamenti
ADD FOREIGN KEY (idDipendente) REFERENCES Dipendenti(idDipendente);

ALTER TABLE RegistroPresenze
ADD FOREIGN KEY (idDipendente) REFERENCES Dipendenti(idDipendente);

ALTER TABLE Sedi 
ADD FOREIGN KEY (idDipendente) REFERENCES Dipendenti(idDipendente);

ALTER TABLE Turni
ADD FOREIGN KEY (idDipendente) REFERENCES Dipendenti(idDipendente);

ALTER TABLE VeicoliClienti
ADD FOREIGN KEY (idVeicolo) REFERENCES Veicoli(idVeicolo);

ALTER TABLE VeicoliClienti
ADD FOREIGN KEY (idCliente) REFERENCES Clienti(idCliente);