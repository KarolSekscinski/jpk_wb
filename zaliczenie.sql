/* 
MSBIZINT 2024L
Imie i nazwisko: Karol Sekscinski
Nr albumu: 319093
*/
IF NOT EXISTS ( SELECT 1 FROM master..sysdatabases d WHERE d.[name] = 'abd24')
BEGIN
    EXEC sp_sqlexec N'create database abd24'
END

USE abd24
GO

-- drop procedure rmv_table
IF NOT EXISTS 
    ( SELECT 1 FROM sysobjects o
        WHERE (o.[name] = 'rmv_table')
        AND (OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
    )
BEGIN
    EXEC sp_sqlExec N'CREATE PROCEDURE dbo.rmv_table AS select 2'
END
-- exec rmv_table
GO

ALTER PROCEDURE dbo.rmv_table (@tab_name nvarchar(100) )
AS
    IF EXISTS 
    ( SELECT 1 FROM sysobjects o
        WHERE (o.[name] = @tab_name)
        AND (OBJECTPROPERTY(o.[ID], N'IsUserTable') = 1)
    )
    BEGIN
        DECLARE @sql nvarchar(1000)
        SET @sql = 'DROP TABLE ' + @tab_name
        EXEC sp_sqlexec @sql
    END
GO
/* tabelki potrzebne do transferu danych - nie mają kluczy gł ani obcych */
EXEC rmv_table @tab_name = 'tmp_wb_na'
GO
/* wszystkie dane tekstowo - potem przetworzymy na typy docelowe */
/* 1:1 odpowiednik pliku tekstowego wb_na*/
CREATE TABLE dbo.tmp_wb_na
(   CC      nvarchar(10)    NOT NULL
,   RM      nchar(6)        NOT NULL /* rok z miesiącem np 202402 rok:2024, miesiąc luty */
,	numer	nvarchar(5)		NOT NULL /* numer wyciagu */
,   DataOd  nvarchar(10)    NOT NULL /* zakladamy format RRRR.MM.DD lub DD.MM.RRRR */
,   DataDo  nvarchar(10)    NOT NULL /* zakladamy format RRRR.MM.DD lub DD.MM.RRRR */
,   DataWyst    nvarchar(10)    NOT NULL /* zakladamy format RRRR.MM.DD lub DD.MM.RRRR */
,   NazwaPodmiotu   nvarchar(100)   NOT NULL
,   NIP    nvarchar(20)    NOT NULL /* nip klienta moze byc z prefixem kraju np PL5555555555 */
,   KodFormularza   nvarchar(20)    NOT NULL
,   KodUrzedu  nvarchar(20)    NOT NULL
,   WersjaSchemy    nvarchar(20)    NOT NULL
)
GO
EXEC rmv_table @tab_name = 'tmp_wb_poz'
/* 1:1 odpowiednik pliku tekstowego wb_poz*/
CREATE TABLE dbo.tmp_wb_poz
(   CC      nvarchar(10)    NOT NULL
,   RM      nchar(6)        NOT NULL /* rok z miesiącem np 202402 rok:2024, miesiąc luty */
,	numer	nvarchar(5)		NOT NULL /* numer wyciagu */
,   Lp      nvarchar(10)    NOT NULL
,   DataOp  nvarchar(10)    NOT NULL /* zakladamy format RRRR.MM.DD lub DD.MM.RRRR */
,   SymbolWaluty    nvarchar(10)    NOT NULL
,   Kwota  nvarchar(20)    NOT NULL
,   Opis   nvarchar(100)   NOT NULL
,   KodNad  nvarchar(20)    NOT NULL
,   KodOdb  nvarchar(20)    NOT NULL
,   NazwaKontr   nvarchar(100)   NOT NULL
,   NIPKontr nvarchar(20)    NOT NULL
)

IF NOT EXISTS ( SELECT 1 FROM sysobjects o WHERE o.[name] = 'Podmiot'
    AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)
)
BEGIN
    CREATE TABLE dbo.Podmiot
    (   PODMIOT_ID nchar(4) NOT NULL CONSTRAINT PK_Podmiot PRIMARY KEY
    ,   NIP             NVARCHAR(20)    NOT NULL
    ,   NAZWA           NVARCHAR(100)   NOT NULL
    ,   KodKraju        NCHAR(2)        NOT NULL DEFAULT N'PL'
    ,	Kraj		NVARCHAR(40) NOT NULL DEFAULT N'Polska'
	,	Wojewodztwo NVARCHAR(40) NOT NULL DEFAULT N'Mazowieckie'
	,	Powiat		NVARCHAR(40) NOT NULL DEFAULT N'Warszawa'
	,	Gmina		NVARCHAR(40) NOT NULL DEFAULT N'Warszawa'
	,	Ulica		NVARCHAR(40) NOT NULL
	,	NrDomu		NVARCHAR(10) NOT NULL
	,	NrLokalu	NVARCHAR(40) NOT NULL
	,	Miejscowosc NVARCHAR(40) NOT NULL DEFAULT 'Warszawa'
	,	KodPocztowy nchar(6) NOT NULL
	,	KodUrzedu	NVARCHAR(5)	NOT NULL
	)
END
GO

IF NOT EXISTS (SELECT 1 FROM Podmiot)
BEGIN
    INSERT INTO Podmiot
    (   PODMIOT_ID
    ,   NIP
    ,   NAZWA
    ,   Ulica
    ,   NrDomu
    ,   NrLokalu
    ,   KodPocztowy
	,	KodUrzedu
    )   VALUES
    (   'PL00'
    ,   'PL0000000001'
    ,   'Firmowa Firma sp. z o.o.'
    ,   'Firmowa'
    ,   '1'
    ,   '125'
    ,   '00-001'
	,	'0001'
    )
    INSERT INTO Podmiot
    (   PODMIOT_ID
    ,   NIP
    ,   NAZWA
    ,   Ulica
    ,   NrDomu
    ,   NrLokalu
    ,   KodPocztowy
	,	KodUrzedu
    )   VALUES
    (   'PL01'
    ,   'PL0000000002'
    ,   'Firmowa Firma sp. z o.o.'
    ,   'Firmowa'
    ,   '2'
    ,   '126'
    ,   '00-001'
	,	'0002'
    )
END
GO

/* tworzymy LOG-i z błedami
** ELOG_N - nagłowek zbioru błedów, kto i gdzie zgłosił
*/
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ELOG_N'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.ELOG_N
	(	id_elog_n		int not null identity CONSTRAINT PK_ELOG_N PRIMARY KEY
	,	opis_n			nvarchar(100) NOT NULL
	,	dt				datetime NOT NULL DEFAULT GETDATE()
	,	u_name			nvarchar(40) NOT NULL DEFAULT USER_NAME()
	,	h_name			nvarchar(100) NOT NULL DEFAULT HOST_NAME()
	) 
END
GO

/* detale błędu
** musi być najpierw wstawiony nagłowek błedu a potem z ID nagłowka błedu wstawiane są detale
*/
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ELOG_D'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.ELOG_D
	(	id_elog_n		int not null 
			CONSTRAINT FK_ELOG_N__ELOG_P FOREIGN KEY
			REFERENCES ELOG_N(id_elog_n)
	,	opis_d			nvarchar(100) NOT NULL
	) 
END
GO


/*
**  Slownik rachunkow bankowych na podstawie kodow Odbiorcy i nadawcy
*/

IF NOT EXISTS (SELECT 1 FROM sysobjects o WHERE o.[name] = 'SRB'
    AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)
)
BEGIN
    CREATE  TABLE dbo.SRB
    (   SZUKANY_KOD             NVARCHAR(10) NOT NULL
        CONSTRAINT  PK_SRB PRIMARY KEY
    ,   RachBankowy				NVARCHAR(26)	NOT NULL
    
    )
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'ABC123')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('ABC123', '12345678901234567890123456')
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'DEF456')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('DEF456', '12345678901234567890123401')
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'ABC987')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('ABC987', '12345678901234567890123402')
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'UIO876')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('UIO876', '12345678901234567890123403')
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'YTA123')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('YTA123', '12345678901234567890123404')
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'POI098')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('POI098', '12345678901234567890123405')
END
GO

IF NOT EXISTS (SELECT 1 FROM SRB v WHERE v.SZUKANY_KOD = 'ACB123')
BEGIN
	INSERT INTO SRB(SZUKANY_KOD, RachBankowy) VALUES ('ACB123', '12345678901234567890123406')
END
GO
/*
**  RACHUNKI BANKOWE
*/
IF NOT EXISTS (SELECT 1 FROM sysobjects o WHERE o.[name] = 'SALDA'
    AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)
)
BEGIN
    CREATE  TABLE dbo.SALDA
    (   Nr_Podmiotu             NCHAR(4) NOT NULL
        CONSTRAINT FK_SALDA_PODMIOT__FK FOREIGN KEY REFERENCES PODMIOT(PODMIOT_ID)
    ,   SaldoPocz				MONEY
	,	SaldoKonc				MONEY
    )
END
GO

IF NOT EXISTS (SELECT 1 FROM SALDA v WHERE v.Nr_Podmiotu = 'PL00')
BEGIN
	INSERT INTO SALDA (Nr_Podmiotu, SaldoPocz, SaldoKonc) VALUES ('PL00', 10000.0, 0.0)
END
GO

IF NOT EXISTS (SELECT 1 FROM SALDA v WHERE v.Nr_Podmiotu = 'PL01')
BEGIN
	INSERT INTO SALDA (Nr_Podmiotu, SaldoPocz, SaldoKonc) VALUES ('PL01', 100000.0, 0.0)
END
GO
/* Slownik adresow klientow */
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'ADRESY'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.ADRESY
	(	Miasto	NVARCHAR(30) NOT NULL
	,	Ulica	NVARCHAR(30) NOT NULL
	,   NIP_KLI	NVARCHAR(20) NOT NULL
	CONSTRAINT  PK_ADRESY PRIMARY KEY
	)
END

IF NOT EXISTS (SELECT 1 FROM ADRESY a WHERE a.NIP_KLI = 'PL5555555555')
BEGIN 
	INSERT INTO ADRESY (NIP_KLI, Miasto, Ulica) VALUES ('PL5555555555', 'Warszawa', 'Pl. Politechniki')
END

IF NOT EXISTS (SELECT 1 FROM ADRESY a WHERE a.NIP_KLI = 'PL5555555550')
BEGIN 
	INSERT INTO ADRESY (NIP_KLI, Miasto, Ulica) VALUES ('PL5555555550', 'Warszawa', 'Niepodleglosci')
END

IF NOT EXISTS (SELECT 1 FROM ADRESY a WHERE a.NIP_KLI = 'PL5555555559')
BEGIN 
	INSERT INTO ADRESY (NIP_KLI, Miasto, Ulica) VALUES ('PL5555555559', 'Warszawa', 'Krakowskie Przedmiescie')
END

IF NOT EXISTS (SELECT 1 FROM ADRESY a WHERE a.NIP_KLI = 'PL5555555558')
BEGIN 
	INSERT INTO ADRESY (NIP_KLI, Miasto, Ulica) VALUES ('PL5555555558', 'Krakow', 'Mickiewicza')
END

IF NOT EXISTS (SELECT 1 FROM ADRESY a WHERE a.NIP_KLI = 'PL5555555557')
BEGIN 
	INSERT INTO ADRESY (NIP_KLI, Miasto, Ulica) VALUES ('PL5555555557', 'Bialystok', 'Kilinskiego')
END

IF NOT EXISTS (SELECT 1 FROM ADRESY a WHERE a.NIP_KLI = 'PL5555555556')
BEGIN 
	INSERT INTO ADRESY (NIP_KLI, Miasto, Ulica) VALUES ('PL5555555556', 'Warszawa', 'Zwirki i Wigury')
END

/* słownik klientów, zamiast przy każdej fakturze trzymać dane klienta
** będziemy dynamicznie tworzyć słownik klientów
*/

IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'KLIENT'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN
	CREATE TABLE dbo.KLIENT
	(	id_kli		int NOT NULL IDENTITY CONSTRAINT PK_KLIENT PRIMARY KEY
	,	Nazwa_Fi	nvarchar(100) NOT NULL
	,	Dane_Adr	nvarchar(210) NOT NULL
	,	NIP_KLI		nvarchar(20) NOT NULL CONSTRAINT FK_KLI_NIP__FK FOREIGN KEY REFERENCES ADRESY(NIP_KLI)
	)
	
END
GO
 

/* Tabela docelowa do przechowywania naglowkow wyciagow bankowych */
IF NOT EXISTS ( SELECT 1 FROM sysobjects o WHERE o.[name] = 'WB'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)
)
BEGIN
	CREATE TABLE dbo.WB
	(	id_kli			INT NOT NULL CONSTRAINT FK_WB__KLIENT FOREIGN KEY REFERENCES KLIENT(id_kli)	/* dla jakiego klienta */
	,	id_wb			INT NOT NULL IDENTITY CONSTRAINT PK_WB1 PRIMARY KEY		/* unikalne id wyciagu dla polaczenia z pozycjami */
	,	PODMIOT_ID		NCHAR(4) NOT NULL CONSTRAINT FK_WB__PODMIOT FOREIGN KEY REFERENCES PODMIOT(PODMIOT_ID) /* odpowiednik CC z importu */
	,	Mies			NCHAR(6) NOT NULL /* odpowiednik RM z importu YYYYMM */
	,	Nr_wb			NVARCHAR(20) NOT NULL	/* Numer wyciagu bankowego */
	,	DataOd			DATETIME NOT NULL /* Data od */
	,	DataDo			DATETIME NOT NULL /* Data do */
	,	DataWys			DATETIME NOT NULL /* Data wystawienia wyciagu bankowego */
	)
END

/* Tabela docelowa do przechowywania pozycji na wyciagu bankowym */
IF NOT EXISTS (SELECT 1 FROM sysobjects o WHERE o.[name] = 'WB_POZ'
	AND (OBJECTPROPERTY(o.[id], 'IsUserTable') = 1)
)
BEGIN
	CREATE TABLE dbo.WB_POZ
	(	id_wb			INT NOT NULL CONSTRAINT FK_WB_POZ__WB FOREIGN KEY REFERENCES WB(id_wb)	/* ktorego wyciagu sa to pozycje */
	,	id_poz			INT NOT NULL IDENTITY CONSTRAINT PK_WB_POZ PRIMARY KEY /* dla potrzeb identyfikacji jednego wiersza wyciagu */
	,	Opis			NVARCHAR(100) NOT NULL
	,	KodNad			NVARCHAR(10) NOT NULL CONSTRAINT FK_WB_POZ__NADKOD FOREIGN KEY REFERENCES SRB(SZUKANY_KOD)
	,	KodOdb			NVARCHAR(10) NOT NULL CONSTRAINT FK_WB_POZ__ODBKOD FOREIGN KEY REFERENCES SRB(SZUKANY_KOD)
	,	Kwota			MONEY NOT NULL /* Kwota wyciagu bankowego */
	,   SymbWaluty		NVARCHAR(10) NOT NULL
	,	DataOp			DATETIME NOT NULL
	)
END
GO

/* procedura który tworzy pustą procedure o zadanej nazwie */
IF NOT EXISTS 
(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'create_empty_proc')
		AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
)
BEGIN
	DECLARE @sql nvarchar(500)
	SET @sql = 'CREATE PROCEDURE dbo.create_empty_proc AS '
	EXEC sp_sqlexec @sql
END
GO
ALTER PROCEDURE dbo.create_empty_proc (@proc_name nvarchar(100))
/* przekazujemy samą nazwę procedura sama dodaje dbo.
*/
AS
	IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = @proc_name)
		AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE PROCEDURE dbo.' + @proc_name + N' AS '
		EXEC sp_sqlexec @sql
	END
GO

/* procedura który tworzy pustą funkcję o zadanej nazwie */
EXEC dbo.create_empty_proc @proc_name = 'create_empty_fun'
GO

ALTER PROCEDURE dbo.create_empty_fun (@fun_name nvarchar(100))
AS
	IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = @fun_name)
		AND		(OBJECTPROPERTY(o.[ID], N'IsScalarFunction') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.' + @fun_name + N' () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END
GO

EXEC dbo.create_empty_fun 'txt2M'

GO

ALTER FUNCTION dbo.txt2M(@txt nvarchar(20) )

RETURNS MONEY
AS
BEGIN
	SET @txt = REPLACE(@txt, N' ', N'')

	IF @txt LIKE '%,%.%' 
	BEGIN
		SET @txt = REPLACE(@txt, N',', N'')
	END ELSE
	IF @txt LIKE '%.%,%'
	BEGIN
		SET @txt = REPLACE(@txt, N'.', N'')
	END
	SET @txt = REPLACE(@txt, N',', N'.')
	RETURN  CONVERT(money, @txt)
END
GO

EXEC dbo.create_empty_fun 'txt2D'
GO

ALTER FUNCTION dbo.txt2D(@txt nvarchar(10) )

RETURNS DATETIME
AS
BEGIN
	IF @txt LIKE N'[1-3][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%'
		RETURN CONVERT(datetime, @txt, 112)

	SET @txt = REPLACE(@txt, N'-', N'.')
	SET @txt = REPLACE(@txt, N'/', N'.')

	IF @txt LIKE N'[1-3][0-9][0-9][0-9]_[0-9][0-9]%'
		RETURN CONVERT(datetime, @txt, 102)
	RETURN CONVERT(datetime, @txt, 104)
END
GO

/* Prawidlowa procedura do walidacji naglowkow */
EXEC dbo.create_empty_proc @proc_name = 'tmp_na_check'
GO
/* Sprawdzam poprawnosc pliku naglowkowego
** Bede sprawdzac czy jest jeden podmiot w danych
** czy jest jeden miesiac
** czy miesiac jest zakonczony
** czy nr wyciagow sie nie powtarzaja
** gdybym cala proc ujeli w transakcje
** wstawianie do err logu tez by podlegalo transakcji
** po ROLLBACK nie byloby zadnych zmian lacznie z pustym error logiem
*/
ALTER PROCEDURE dbo.tmp_na_check(@err int = 0 output)
AS
	DECLARE @cnt INT, @en NVARCHAR(100), @id_en INT

	SET @err = 0

	/* Ponizej naglowek ew. bledu */
	SET @en = 'Blad w procedurze: Wyciag Bankowy: WB_n_process / '
	
	/* Sprawdzam czy plik naglowkowy nie jest pusty */
	SELECT @cnt = COUNT(*) FROM tmp_wb_na
	IF @cnt = 0
	BEGIN
		SET @en = @en + 'Plik nagłowkowy jest pusty.'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) VALUES (@id_en, '0 wierszy w tmp_wb_na')

		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

	/* Sprawdzam czy jest jeden podmiot w pliku */
	SELECT @cnt = COUNT(DISTINCT p.CC) FROM tmp_wb_na p

	IF @cnt > 1
	BEGIN
		SET @en = @en + 'Więcej jak jeden podmiot w pliku.'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
			SELECT DISTINCT @id_en, t.CC
			FROM tmp_wb_na t
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

	/* Sprawdzam czy w pliku jest jeden miesiac */
	SELECT @cnt = COUNT(DISTINCT t.CC) FROM tmp_wb_na t
	
	IF @cnt > 1
	BEGIN
		SET @en = @en + N'Więcej jak jeden miesiąc w pliku.'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
			SELECT DISTINCT @id_en, t.rm
			FROM tmp_wb_na t
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

	/* Sprawdzam czy podany podmiot (CC) znajduje sie obecnie w tabeli podmiotow */
	DECLARE @cc NVARCHAR(10)
	SELECT @cc = MAX(t.CC) FROM tmp_wb_na t

	IF NOT EXISTS (SELECT 1 FROM PODMIOT p WHERE p.PODMIOT_ID = @CC )
	BEGIN
		SET @en = @en + N'Podmiotu o tym kodzie nie ma w słowniku.'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
			SELECT DISTINCT @id_en, t.CC
			FROM tmp_wb_na t
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

	/* Sprawdzam czy miesiac obecny w wyciagu minal */
	DECLARE @ym_max nchar(6)
	SET @ym_max = CONVERT(nchar(6), GETDATE(), 112) --czyli rok i miesiac z dzisiaj

	IF EXISTS ( SELECT 1 FROM tmp_wb_na t WHERE t.rm >= @ym_max )
	BEGIN
		SET @en = @en + 'Można raportować TYLKO miesiące które MINĘŁY'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
			SELECT DISTINCT @id_en, t.rm
				FROM tmp_wb_na t WHERE t.rm >= @ym_max

		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END
	
	/* Sprawdzam czy numery wyciagow sie nie powtarzaja */
	IF EXISTS ( SELECT t.numer
				FROM tmp_wb_na t
				GROUP BY t.numer
				HAVING COUNT(t.numer) > 1
	)
	BEGIN
		SET @en = @en + 'Mamy powtarzające się numery wyciagow'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT DISTINCT 
			@id_en, N'Podm:' + n.CC 
			+ N' / NUM:' + n.numer
			+ N' / MIES:' + n.rm
			+ N'  / Ile razy:' + LTRIM(RTRIM(STR(x.ile_razy,10,0)))
			FROM tmp_wb_na n
			JOIN (	SELECT t.numer, COUNT(t.numer) AS ile_razy
				FROM tmp_wb_na t
				GROUP BY t.numer
				HAVING COUNT(t.numer) > 1
				) x ON (x.numer = n.numer)		
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END
GO


EXEC dbo.create_empty_proc @proc_name = 'tmp_poz_check'
GO
/* Bede sprawdzac czy jest jeden podmiot w danych
** gdybym caly proc ujal w transakcje
** wstawianie do err logu tez by podlegalo transakcji
** po ROLLBACK nie byloby zadnych zmian laczenie z pustym error logiem
*/

ALTER PROCEDURE dbo.tmp_poz_check (@err int = 0 output)
AS
	EXEC dbo.tmp_na_check @err = @err output

	IF NOT (@err = 0)
	BEGIN
		RAISERROR(N'Błedy w nagłowkach', 16, 3)
		RETURN -1
	END
	DECLARE @cnt int, @en nvarchar(100), @id_en int
	SET @en = 'Blad w procedurze: tmp_poz_check / '

	/* Czy wszystkie naglowki maja swoje pozycje? */
	SELECT @cnt = COUNT(*)
		FROM tmp_wb_na  n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_poz  d
			WHERE	d.CC	= n.CC
			AND		d.numer = n.numer
			AND		d.RM	= n.RM
		)
	
	IF @cnt > 0
	BEGIN
		SET @en = @en + 'Mamy nagłowki bez pozycji'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT @id_en, N'Podm:' + n.CC 
			+ N' / NUM:' + n.numer
			+ N' / MIES:' + n.rm
		FROM tmp_wb_na n
		WHERE NOT EXISTS 
		( SELECT 1
			FROM tmp_wb_poz d
			WHERE	d.CC	= n.CC
			AND		d.numer = n.numer
			AND		d.RM	= n.RM
		)
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

	/* Czy kody nadawcy sa w slowniku rachunkow bankowych? */
	IF EXISTS
	( SELECT * 
			FROM tmp_wb_poz d
			WHERE NOT EXISTS
			( SELECT * FROM SRB v
				WHERE v.SZUKANY_KOD = d.KodNad
			)
	)
	BEGIN
	SET @en = @en + 'Mamy rachunek bankowy nadawcy ktorego nie ma w slowniku'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT DISTINCT @id_en, d.KodNad
			FROM tmp_wb_poz d
			WHERE NOT EXISTS 
			( SELECT 1 FROM SRB v
				WHERE d.KodNad = v.SZUKANY_KOD
			)
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END
		


	/* Czy kody odbiorcy sa w slowniku rachunkow bankowych? */
	IF EXISTS
	( SELECT * 
			FROM tmp_wb_poz d
			WHERE NOT EXISTS
			( SELECT * FROM SRB v
				WHERE v.SZUKANY_KOD = d.KodOdb
			)
	)
	BEGIN
	SET @en = @en + 'Mamy rachunek bankowy odbiorcy ktorego nie ma w slowniku'
		INSERT INTO ELOG_N(opis_n) VALUES (@en)
		SET @id_en = SCOPE_IDENTITY()

		INSERT INTO ELOG_D(id_elog_n, opis_d) 
		SELECT DISTINCT @id_en, d.KodOdb
			FROM tmp_wb_poz d
			WHERE NOT EXISTS 
			( SELECT 1 FROM SRB v
				WHERE d.KodOdb = v.SZUKANY_KOD
			)
		RAISERROR(@en, 16, 4)
		SET @err = 1
		RETURN -1
	END

	/* Dodajemy nowego klienta */
	INSERT INTO KLIENT (Nazwa_Fi, Dane_Adr, NIP_KLI)
	SELECT DISTINCT n.[NazwaPodmiotu], dbo.DANE_ADR_KLI(a.Miasto, a.Ulica), n.NIP
		FROM tmp_wb_na n
	JOIN ADRESY a ON (a.NIP_KLI = n.NIP)
	WHERE NOT EXISTS 
		( SELECT * FROM KLIENT KW
		WHERE (KW.Nazwa_Fi = n.[NazwaPodmiotu])
		AND (KW.NIP_KLI = n.[NIP])
		)

	/* petla po naglowkach aby stworzyc wyciagi w docelowych tabelach */
	DECLARE CC INSENSITIVE CURSOR FOR
		SELECT n.CC, n.RM, n.numer
		, dbo.txt2D(n.DataOd) AS DataOd
		, dbo.txt2D(n.DataDo) AS DataDo
		, dbo.txt2D(n.DataWyst) AS DataWyst
		, (SELECT MAX(id_kli) AS id_kli
			FROM KLIENT k
			WHERE (k.Nazwa_Fi = n.[NazwaPodmiotu])
			AND (k.NIP_KLI = n.[NIP])
			) AS id_kli
		FROM tmp_wb_na n
	DECLARE @CC nchar(4), @mies nchar(6), @numer nvarchar(20)
	, @dOd datetime, @dDo datetime, @dWys datetime, @id_kl int, @id_wb int
	, @TrCnt int
	OPEN CC
	FETCH NEXT FROM CC INTO @CC, @mies, @numer, @dOd, @dDo, @dWys, @id_kl
	/* MUSIMY SKASOWAC WSZYSTKIE POZYCJE I WYCIAGI DLA @CC i @MIES */
	IF @@FETCH_STATUS = 0
	BEGIN
		/* Kasujemy pozycje do wyciagow z calego miesiaca */
		DELETE FROM WB_POZ WHERE WB_POZ.id_wb IN
			(SELECT WB.id_wb FROM WB WHERE WB.Mies=@mies AND WB.PODMIOT_ID = @CC)
		/* Kasujemy naglowki wyciagu */
		DELETE FROM WB WHERE WB.Mies=@mies AND WB.PODMIOT_ID = @CC
	END
	/* Dodanie naglowka wyciagu i pozycji musi byc w ramach jednej transakcji !*/
	WHILE (@@FETCH_STATUS = 0) AND (@err = 0)
	BEGIN
		/* Dodawanie naglowka i pozycji ujmujemy w jedna transakcje */
		SET @TrCnt = @@TRANCOUNT
		IF @TrCnt = 0 /* Nie ma zadnej transakcji - tworzymy nowa */
			BEGIN TRAN TR_POZ_NA
		ELSE /* Uzywamy SAVETRAN jak juz jest wczesniej zaczeta tr */
			SAVE TRAN TR_POZ_NA
		/* Wstawiamy naglowek wyciagu */
		INSERT INTO WB (id_kli, PODMIOT_ID, Mies, Nr_wb, DataOd, DataDo, DataWys)
			VALUES (@id_kl, @CC, @mies, @numer, @dOd, @dDo, @dWys)
		/* Pobieramy nadane wyciagowi id */
		SELECT @err = @@ERROR, @id_wb = SCOPE_IDENTITY()

		IF @err = 0
		BEGIN
			/* Jesli udalo sie wstawic naglowek to wstawiamy pozycje */
			INSERT INTO WB_POZ (id_wb, Opis, Kwota, KodNad, KodOdb, SymbWaluty, DataOp)
			SELECT @id_wb
			, p.Opis
			, dbo.txt2M(p.Kwota) /* Konwertujemy kwoty z txt */
			, p.KodNad
			, p.KodOdb
			, p.SymbolWaluty
			, dbo.txt2D(p.DataOp)
			FROM tmp_wb_poz p
			WHERE (p.CC = @CC) AND (p.numer = @numer) AND (p.RM = @mies)

			/* Aktualizujemy saldo */
			UPDATE SALDA
				SET SaldoKonc = SaldoPocz - ISNULL((
				SELECT SUM(WB_POZ.Kwota)
				FROM WB_POZ
				INNER JOIN WB ON WB.id_wb = WB_POZ.id_wb
				WHERE WB.PODMIOT_ID = SALDA.Nr_Podmiotu
			), 0)
			SET @err = @@ERROR
		END

		IF @err = 0 /* wszystko ok */
		BEGIN
			IF @TrCnt = 0 /* Zapisz zmiany */
				COMMIT TRAN TR_POZ_NA
		END
		ELSE /* Odwolaj zmiany */
			ROLLBACK TRAN TR_POZ_NA

		FETCH NEXT FROM CC INTO @CC, @mies, @numer, @dOd, @dDo, @dWys, @id_kl
	END
	CLOSE CC
	DEALLOCATE CC
GO

EXEC dbo.create_empty_fun N'DANE_ADR_KLI'
GO

ALTER FUNCTION dbo.DANE_ADR_KLI (@miasto nvarchar(50), @ulica nvarchar(100))
RETURNS NVARCHAR(100)
AS
BEGIN
	DECLARE @addr nvarchar(100)
	SET @addr = LTRIM(RTRIM(@miasto)) + N',ul.' + @ulica
	RETURN @addr
END
GO

/* Ponizej przyklad jak mozna rozwiazac problem ze inne formaty obowiazuja
** dla roznych miesiecy - ja zrobie tylko jeden ale ponizej ilustracja
** rzad oglasza nowy format i od jakiego dnia obowiazuje (dokladnie od jakiego miesiaca)
** my robimy pod nowy format procedure sql i zapamietujemy nazwe procedury
** oraz od kiedy obowiazuje w tabeli
** teraz wystarczy napisac procedure ktora znajdzie i wywola
** odpowiednia procedure w zaleznosci od miesiaca, ktory raportujemy
*/

IF NOT EXISTS ( SELECT 1 FROM sysobjects o WHERE o.[name] = 'PROC_JPK'
	AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
)
BEGIN	
	CREATE TABLE dbo.PROC_JPK
	(	[typ] NVARCHAR(20) NOT NULL
	,	od_mies	NCHAR(6) NOT NULL
	,	CONSTRAINT PK_PROC_JPK PRIMARY KEY ([typ], od_mies)
	,   sql_proc NVARCHAR(150) NOT NULL
	)
	INSERT INTO PROC_JPK([typ], od_mies, sql_proc) VALUES ('JPK_WB', '201901', 'jpk_wb0')
	INSERT INTO PROC_JPK([typ], od_mies, sql_proc) VALUES ('JPK_WB', '202001', 'jpk_wb1')
	INSERT INTO PROC_JPK([typ], od_mies, sql_proc) VALUES ('JPK_WB', '202101', 'jpk_wb2')
	INSERT INTO PROC_JPK([typ], od_mies, sql_proc) VALUES ('JPK_WB', '202201', 'jpk_wb3')
END
GO

EXEC dbo.create_empty_proc @proc_name = 'jpk_wb0'
EXEC dbo.create_empty_proc @proc_name = 'jpk_wb1'
EXEC dbo.create_empty_proc @proc_name = 'jpk_wb2'
EXEC dbo.create_empty_proc @proc_name = 'jpk_wb3'
GO
ALTER PROCEDURE dbo.jpk_wb0 (@rm nchar(6))
AS
	SELECT @rm AS [JPK_WB0_za_mies]
GO
ALTER PROCEDURE dbo.jpk_wb1 (@rm nchar(6))
AS
	SELECT @rm AS [JPK_WB1_za_mies]
GO
ALTER PROCEDURE dbo.jpk_wb2 (@rm nchar(6))
AS
	SELECT @rm AS [JPK_WB2_za_mies]
GO
ALTER PROCEDURE dbo.jpk_wb3 (@rm nchar(6))
AS
	SELECT @rm AS [JPK_WB3_za_mies]
GO

EXEC dbo.create_empty_proc @proc_name = 'run_jpk'
GO
/* Szukamy najpierw jaka procedure obowiazuje w podanym miesiacu */
ALTER PROCEDURE dbo.RUN_JPK (@typ NVARCHAR(20) = N'JPK_WB', @rm NCHAR(6))
AS
	DECLARE @m NCHAR(6), @sql_proc NVARCHAR(100), @sql NVARCHAR(200)

	SELECT @m = MAX(p.od_mies)
	FROM PROC_JPK p
	WHERE p.od_mies <= @rm
	AND p.[typ] = @typ

	IF @m IS NULL
	BEGIN
		RAISERROR('Brak raportu dla typu %s i miesiąca %s', 16, 3, @typ, @rm)
		RETURN -1
	END

	SELECT @sql_proc = p.sql_proc 
		FROM PROC_JPK p 
		WHERE p.typ = @typ AND p.od_mies = @m

	SET @sql = 'EXEC ' + @sql_proc + ' @rm=''' + @rm + ''''  
	EXEC sp_sqlexec @sql
GO


/* GENEROWANIE PLIKU XML Z TABEL WB ORAZ WB_POZ */
EXEC dbo.create_empty_fun @fun_name = 'SAFT_RMV_PREFIX'
GO

/* Funkcja usuwa kod kraju z numeru NIP */

ALTER FUNCTION dbo.SAFT_RMV_PREFIX(@msg NVARCHAR(20))
RETURNS NVARCHAR(20)
AS
BEGIN
	IF LEN(@msg) < 3
		RETURN @msg
	IF (LEFT(@msg,1) BETWEEN 'a' AND 'z') OR (LEFT(@msg,1) BETWEEN 'A' AND 'Z')
		RETURN RTRIM(SUBSTRING(@msg,3,20))
	RETURN RTRIM(@msg)
END
GO

EXEC dbo.create_empty_proc @proc_name = 'SAFT_INI_DATA'
GO
/* TA FUNKCJA MOZE BYC MALO PRZYDATNA BO MAMY PIERWSZY I OSTATNI DZIEN MIESIACA W DANYCH */
ALTER PROCEDURE dbo.SAFT_INI_DATA(@ym nchar(6), @d1 datetime = null output, @dN datetime = null output)
/*
declare @d1 datetime,  @dn datetime
EXEC dbo.SAFT_INI_DATA @ym = '202303', @d1=@d1 output, @dn=@dn output
SELECT @d1, @dn
-- (No column name)	(No column name)
2023-03-01 00:00:00.000	2023-03-31 00:00:00.000
*/

AS
	/* my dyspnujemy miesiacem a jpk wymaga daty pierwszego i ost. dnia miesiąca */
	/* dodajemy 01 jako pierwszy dzien miesiaca i budujemy date */
	SET @d1 = convert(datetime, substring(@ym,5,2) + '/01/' + left(@ym,4),101)	
	/* do 1szzego dnia dodajemy miesiac i odejmujemy jeden dzien i dostajemy ostatni dzien mies */
	SET @dN = dateadd(DD, -1, dateadd(MM, 1, @d1))
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_CLEAR_TXT'
GO

ALTER FUNCTION dbo.SAFT_CLEAR_TXT(@msg nvarchar(256) )
/* wyczyść pole tekstowe z wrażliwych znaków */
RETURNS nvarchar(256)
AS
BEGIN
	IF (@msg IS NULL)  OR (RTRIM(@msg) = N'')
		RETURN N''

	SET @msg = LTRIM(RTRIM(@msg))
	SET @msg = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@msg,'\n',N' '),N'<',N'?'),N'>','?'),N':',N'?'),N'\',N'?')
	SET @msg = REPLACE(@msg,N'/',N'!')
	RETURN RTRIM(LEFT(@msg,255)) /* limit for SAFT text field is 255 */
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_DATE'
GO

ALTER FUNCTION dbo.SAFT_DATE(@d datetime )
/* format daty dopuszczalny w plikach JPK */
RETURNS nchar(10)
AS
BEGIN
	RETURN CONVERT(nchar(10), @d, 120)
END
GO


EXEC dbo.create_empty_fun @fun_name = 'SAFT_GET_AMT'
GO


ALTER FUNCTION dbo.SAFT_GET_AMT(@amt money )
/* format kwotowy dopuszczalny w XML */
RETURNS nvarchar(20)
AS
BEGIN
	IF @amt IS NULL
		RETURN N''
	RETURN RTRIM(LTRIM(STR(@amt,18,2)))
END
GO
EXEC dbo.create_empty_proc @proc_name = 'JPK_WB_3'
GO

ALTER PROCEDURE [dbo].[JPK_WB_3]
(	@ym				NCHAR(6)
,	@xml			XML					=  null output
,	@curr_code		NCHAR(3)			= N'PLN'
,	@return			NVARCHAR(20)		= N'XML'
,	@CC				NCHAR(4)			= N'PL00'
,	@debug			BIT					= 0
,	@correction		BIT					= 0
,	@corr_no		INT					= 0
)
AS
		DECLARE @tname NVARCHAR(20), @d1 datetime, @dN datetime, @selerId int

		SET @tname = '#TI'

		EXEC dbo.SAFT_INI_DATA @ym = @ym, @d1=@d1 output, @dN=@dN output

		/* #TI Przygotowujemy naglowki do wyciagow bankowych */

		SELECT
			wb.PODMIOT_ID									AS src
		,	dbo.SAFT_DATE(wb.DataWys)						AS bank_sta
		,	wb.Nr_wb										AS bank_no
		,	k.Nazwa_Fi										AS cust_name
		,	k.Dane_Adr										AS cust_addr
		,	p.NAZWA											AS seler_name
		,	p.KodPocztowy + N' ' + p.Miejscowosc + N',' 
			+ p.Ulica + N' ' + p.NrDomu + 
			IIF(LTRIM(p.NrLokalu)=N'',
			 N'', N' m: ' + p.NrLokalu )					AS seler_addr
		,	s.RachBankowy									AS IBAN_no
		,	''												AS seler_reason
		,	N'WB'											AS [bank_type]
		,	N''												AS corr_reason
		,	ISNULL(NULL, N'')								AS corr_no
		,	N''												AS corr_period
		
		INTO #TI
		FROM WB wb (NOLOCK)
		join WB_POZ wp (NOLOCK) ON (wp.id_wb = wb.id_wb)
		join KLIENT k (NOLOCK) ON (k.id_kli = wb.id_kli)
		join Podmiot p (NOLOCK) ON (p.PODMIOT_ID = wb.PODMIOT_ID)
		join SRB s (NOLOCK) ON (s.SZUKANY_KOD = wp.KodNad)
		WHERE (wb.Mies = @ym) AND (wb.PODMIOT_ID = @CC)
		ORDER BY wb.Nr_wb

		/* #TIT Przygotowujemy pozycji do wyciagu bankowego */
		SELECT 
			wp.id_wb										AS wb_id
		,	w.Nr_wb											AS wb_no
		,	s.RachBankowy									AS klient_IBAN
		,	wp.Opis											AS item_desc
		,	wp.SymbWaluty									AS currency
		,	dbo.SAFT_DATE(wp.DataOp)						AS date_operation
		,	dbo.SAFT_GET_AMT(wp.Kwota)						AS value
		,	k.Nazwa_Fi										AS kli_name
		INTO #TIT
		FROM WB_POZ wp (NOLOCK)
		join WB w ON (wp.id_wb = w.id_wb)
		join Podmiot p (NOLOCK) ON (p.PODMIOT_ID = w.PODMIOT_ID)
		join SRB s (NOLOCK) ON (s.SZUKANY_KOD = wp.KodOdb)
		join KLIENT k (NOLOCK) ON (k.id_kli = w.id_kli)
		WHERE (w.Mies = @ym) AND (w.PODMIOT_ID = @CC)
		ORDER BY w.Nr_wb


		SET @xml = null
		
		;WITH XMLNAMESPACES(N'http://jpk.mf.gov.pl/wzor/2019/09/27/09271/' AS tns
			, N'http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/' AS etd)

		SELECT @xml = 
			( SELECT 
			/* Naglowek */
				( SELECT 
					N'1-0'									AS [tns:KodFormularza/@wersjaSchemy]	/*schema version */
				,	N'JPK_WB (3)'							AS [tns:KodFormularza/@kodSystemowy]	/* System code, was fixed in XSD */
				,	N'JPK_WB'								AS [tns:KodFormularza]					/* SAFT ID - fixed */
				,	N'3'									AS [tns:WariantFormularza]				/* SAFT variant - fixed */
				,	N'1'									AS [tns:CelZlozenia]					/* reason - fixed */
				,	GETDATE()								AS [tns:DataWytworzeniaJPK]				/* creation data */
				,	dbo.SAFT_DATE(@d1)						AS [tns:DataOd]							/* from date */
				,	dbo.SAFT_DATE(@dN)						AS [tns:DataDo]							/* to date */
				,	N'PLN'									AS [tns:DomyslnyKodWaluty]				/* default currency code */
				,	p.KodUrzedu								AS [tns:KodUrzedu]						/* office code */
				FROM Podmiot (NOLOCK) p WHERE p.PODMIOT_ID = @CC
				FOR XML PATH('tns:Naglowek'), TYPE
				),
				/* Podmiot1 */
				( SELECT
					( SELECT 
						dbo.SAFT_RMV_PREFIX(p.NIP)			AS [etd:NIP]
					,	dbo.SAFT_CLEAR_TXT(p.NAZWA)			AS [etd:PelnaNazwa]
					FROM Podmiot (NOLOCK) p WHERE p.PODMIOT_ID = @CC
					FOR XML PATH('tns:IdentyfikatorPodmiotu'), TYPE
					),
					( SELECT
						p.KodKraju							AS [etd:KodKraju]
					,	p.Wojewodztwo						AS [etd:Wojewodztwo]
					,	p.Powiat							AS [etd:Powiat]
					,	p.Gmina								AS [etd:Gmina]
					,	p.Ulica								AS [etd:Ulica]
					,	p.NrDomu							AS [etd:NrDomu]
					,	p.NrLokalu							AS [etd:NrLokalu]
					,	p.Miejscowosc						AS [etd:Miejscowosc]
					,	p.KodPocztowy						AS [etd:KodPocztowy]
					FROM Podmiot (NOLOCK) p WHERE p.PODMIOT_ID = @CC
					FOR XML PATH('tns:AdresPodmiotu'), TYPE
					)
				FOR XML PATH('tns:Podmiot1'), TYPE
				),
				/* Numer rachunku */
				( SELECT
					MAX(s.RachBankowy)							AS [tns:NumerRachunku]
					FROM WB_POZ wp
					join SRB s (NOLOCK) ON (wp.KodNad = s.SZUKANY_KOD)

				FOR XML PATH('tns:NumerRachunku'), TYPE
				),
				/* Salda poczatkowe i koncowe */
				( SELECT
					s.SaldoPocz								AS [tns:SaldoPoczatkowe]
				,	s.SaldoKonc								AS [tns:SaldoKoncowe]
					FROM SALDA s (NOLOCK) WHERE s.Nr_Podmiotu = @CC

				FOR XML PATH('tns:Salda'), TYPE
				),
				/* WyciagWiersz */
				( SELECT
					t.wb_no									AS [tns:NumerWiersza]
				,	t.date_operation						AS [tns:DataOperacji]
				,	t.kli_name								AS [tns:NazwaPodmiotu]
				,	t.item_desc								AS [tns:OpisOperacji]
				,	t.value									AS [tns:KwotaOperacji]
				,	t.klient_IBAN							AS [tns:RachunekBankowyKlienta]
				
					FROM #TIT t

				FOR XML PATH('tns:WyciagWiersz'), TYPE
				),
				/* WyciagCtrl */
				( SELECT
					( SELECT 
						COUNT(*)							
						FROM #TIT t						
					FOR XML PATH('tns:LiczbaWierszy'), TYPE
					),
					( SELECT
						dbo.SAFT_GET_AMT(ISNULL(
							(SELECT 
							SUM(wp.Kwota)
							FROM WB_POZ wp (NOLOCK)
							INNER JOIN WB wb (NOLOCK) ON (wb.id_wb = wp.id_wb)
							WHERE wb.PODMIOT_ID = @CC
							), 0))
					FOR XML PATH('tns:SumaObciazen'), TYPE
					),
					( SELECT
						N'0' 								
					FOR XML PATH('tns:SumaUznan'), TYPE
					)

				FOR XML PATH('tns:WyciagCtrl'), TYPE
				)
			FOR XML PATH(''), TYPE, ROOT('tns:JPK')
			)


			SET @xml.modify('declare namespace tns = "http://jpk.mf.gov.pl/wzor/2019/09/27/09271/"; insert attribute xsi:schemaLocation{"http://jpk.mf.gov.pl/wzor/2019/09/27/09271/ schema.xsd"} as last into (tns:JPK)[1]')
				
			IF @return = 'headers'
				SELECT i.* FROM #TI i
			ELSE
			IF @return = 'details'
				SELECT t.* FROM #TIT t
			ELSE
				SELECT @xml as [xml]
GO

/* test xml */
/*
SELECT * FROM KLIENT
SELECT * FROM WB
SELECT * FROM WB_POZ

EXEC JPK_WB_3 @ym='202403', @CC = 'PL00'
*/