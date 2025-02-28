USE `Cadeia` ;

DELIMITER $
CREATE PROCEDURE RemoverCela(IN id INT)
BEGIN
	UPDATE Cela 
    SET Ocupacao = Ocupacao - 1 
    WHERE idCela = id;
END $
DELIMITER ;

DELIMITER //
CREATE PROCEDURE TrocarCela(
    IN prisioneiro_id INT,
    IN nova_cela_id INT
)
BEGIN
    DECLARE capacidade_nova INT;
    DECLARE ocupacao_nova INT;
    
    -- Obtém a ocupação da nova cela
    SELECT ocupacao, capacidade_nova INTO ocupacao_nova, capacidade_nova
    FROM celas
    WHERE id = nova_cela_id;
    -- Verifica se a nova cela não está completamente ocupada
    IF capacidade_nova > Ocupacao_nova THEN
        -- Atualiza a ocupação da cela antiga
       CALL RemoverCela((SELECT cela_id FROM Prisioneiro WHERE id = prisioneiro_id));
        
                -- Atualiza a cela do prisioneiro
			IF capacidade_nova = 1 THEN
				UPDATE Prisioneiro
				SET cela_id = nova_cela_id, Visitas = FALSE
				WHERE id = prisioneiro_id;
			ELSE 
				UPDATE Prisioneiro
				SET cela_id = nova_cela_id
				WHERE id = prisioneiro_id;
			END IF;
        -- Atualiza a ocupação da nova cela
        UPDATE celas
        SET ocupacao = ocupacao_nova + 1
        WHERE id = nova_cela_id;
        SELECT 'Troca de cela bem-sucedida.' AS mensagem;
    ELSE
        SELECT 'A nova cela está completamente ocupada.' AS mensagem;
    END IF;
END //
DELIMITER ;

DELIMITER $
CREATE PROCEDURE GetProximaCela(IN id_cadeia INT, OUT id_cela INT)
BEGIN
DECLARE ID_aux INT;
SELECT idCela INTO ID_aux FROM ( SELECT idCela, (Capacidade - Ocupacao) AS difference, Ala_idAla FROM Cela) AS subquery 
	WHERE difference > 0
	ORDER BY difference ASC, Ala_idAla ASC
	LIMIT 1;

UPDATE Cela 
SET Ocupacao = Ocupacao + 1 
WHERE idCela = ID_aux;

SET id_cela = ID_aux;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE AdicionarPrisioneiro(IN ExProfissao VARCHAR(50), IN Visitas BOOL, IN Nome VARCHAR(45), IN PenaRestante INT, IN Tarefa ENUM('LIMPEZA', 'OFICINA', 'FOLGA'), IN Oficina_idOficina INT, IN DataDeNascimento DATE, IN ID_cadeia INT)
Adiçao:BEGIN
DECLARE proximaCela INT;
       DECLARE vErro INT DEFAULT 0;
    DECLARE CONTINUE HANDLER 
        FOR SQLEXCEPTION 
			SET vErro = 1;

START TRANSACTION;
IF ((select exists (select 1 from Cadeia where ID = ID_cadeia)) = 1) THEN
	IF ((Select (Capacidade - Ocupacao) From Cadeia Where ID = ID_cadeia) > 0) THEN 
		IF ((Oficina_idOficina IS NULL AND (Tarefa  != 'OFICINA')) OR (((select exists (select 1 from Oficina where idOficina = Oficina_idOficina)) = 1) AND Tarefa = 'OFICINA')) THEN
        IF ((PenaRestante >= 0) AND (PenaRestante <= 9132)) THEN
        call GetProximaCela(ID_cadeia, proximaCela);
        
		IF (vErro = 1) THEN
        ROLLBACK;
		SELECT 'Transação abortada - Falha ao obter a próxima cela' AS MSG;
		LEAVE Adiçao;
		END IF;
        
		INSERT INTO Prisioneiro (ExProfissao, Visitas, Nome, PenaRestante, Tarefa, Oficina_idOficina, Cela_idCela, DataDeNascimento, Cadeia_Id)
		VALUES(ExProfissao, Visitas, Nome, PenaRestante, Tarefa, Oficina_idOficina, proximaCela, DataDeNascimento, ID_cadeia);
        
		IF (vErro = 1) THEN
		ROLLBACK;
		SELECT 'Transação abortada - Falha ao inserir prisoneiro' AS MSG;
		LEAVE Adiçao;
		END IF;
        
        UPDATE Cadeia 
        SET Ocupacao = Ocupacao + 1
        WHERE ID = ID_cadeia;
        
		IF (vErro = 1) THEN
		ROLLBACK;
		SELECT 'Transação abortada - Falha ao dar update da cadeia' AS MSG;
		LEAVE Adiçao;
		END IF;
        
		SELECT 'Adição bem-sucedida.' AS mensagem;
        ELSE SELECT 'Pena Inválida, a pena tem de estar compreendida entre 0 e 9132 (25 anos em dias)' AS mensagem;
        END IF;
        ELSE  SELECT 'Oficina inexistente' AS mensagem;
        END IF;
    ELSE SELECT 'A Cadeia está cheia' AS mensagem;
    END IF;
ElSE SELECT 'Cadeia Inexistente' AS mensagem;
END IF;
COMMIT;
END $
DELIMITER ;

DELIMITER $

CREATE PROCEDURE RemoverPrisioneiro(IN Id_prisioneiro INT)
BEGIN
    DECLARE ID_cadeia INT;

    IF ((SELECT EXISTS (SELECT 1 FROM Prisioneiro WHERE idPrisioneiro = Id_prisioneiro)) = 1) THEN
        CALL RemoverCela((SELECT Cela_idCela FROM Prisioneiro WHERE idPrisioneiro = Id_prisioneiro));
        SELECT cadeia_ID INTO ID_cadeia FROM Prisioneiro WHERE idPrisioneiro = Id_prisioneiro LIMIT 1;
        UPDATE Cadeia 
        SET Ocupacao = Ocupacao - 1
        WHERE ID = ID_cadeia;
        DELETE FROM PRISIONEIRO
        WHERE idPrisioneiro = Id_prisioneiro;
        SELECT 'Remoção bem-sucedida.' AS mensagem;
    ELSE
        SELECT 'Prisioneiro Inexistente' AS mensagem;
    END IF;
END $

DELIMITER ;


DELIMITER $
CREATE PROCEDURE ShowNumPrisioneiros(IN Id_cadeia INT)
BEGIN
	IF ((select exists (select 1 from Cadeia where ID = ID_cadeia)) = 1) THEN
    SELECT CONCAT('A prisão ', Nome, ' possui ', Ocupacao, ' prisioneiros') AS MSG
	FROM Cadeia
	WHERE ID = Id_cadeia;
    ELSE SELECT ('Cadeia inexistente') AS MSG;
	END IF;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE ShowPrisioneirosOrdenadosPorTempoRestante(IN Id_cadeia INT)
BEGIN
	IF ((select exists (select 1 from Cadeia where ID = ID_cadeia)) = 1) THEN
    SELECT * FROM Prisioneiro
    WHERE Cadeia_Id = Id_cadeia
    ORDER BY PenaRestante ASC;
    ELSE SELECT ('Cadeia inexistente') AS MSG;
	END IF;
END $
DELIMITER ;

DELIMITER $

CREATE PROCEDURE DiminuiPena(IN Id_prisioneiro INT, OUT funcionou INT)
DiminuiPena:BEGIN
    DECLARE vErro INT DEFAULT 0;
    DECLARE valor_pena_restante INT;

    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET vErro = 1;
    START TRANSACTION;

    UPDATE Prisioneiro
    SET PenaRestante = PenaRestante - 1
    WHERE idPrisioneiro = Id_prisioneiro;

    IF (vErro = 1) THEN 
        ROLLBACK;
        SET funcionou = 0;
        LEAVE DiminuiPena;
    END IF;

    SELECT PenaRestante INTO valor_pena_restante
    FROM Prisioneiro
    WHERE idPrisioneiro = Id_prisioneiro;

    IF vErro = 1 THEN 
        ROLLBACK;
        SET funcionou = 1;
        LEAVE DiminuiPena;
    END IF;

    IF valor_pena_restante < 0 THEN
        CALL RemoverPrisioneiro(Id_prisioneiro);
         IF (vErro = 1) THEN 
        ROLLBACK;
        SET funcionou = 2;
        LEAVE DiminuiPena;
    END IF;
	
    END IF;

    SET funcionou = 3;
    COMMIT;
END $

DELIMITER ;

DELIMITER $
CREATE PROCEDURE TrocarOficinaPrisioneiro(IN ID_prisioneiro INT, IN ID_oficina INT) 
Atualizar:BEGIN
    DECLARE vErro INT DEFAULT 0;
    DECLARE CONTINUE HANDLER 
        FOR SQLEXCEPTION 
			SET vErro = 1;
START TRANSACTION;
		IF ((ID_prisioneiro IS NOT NULL) AND ((select exists (SELECT 1 FROM Prisioneiro WHERE idPrisioneiro = ID_prisioneiro)) = 1)) THEN
           IF (ID_oficina IS NOT NULL AND ((select exists (select 1 from Oficina where idOficina = ID_oficina)) = 1)) THEN
        UPDATE Prisioneiro
        SET Oficina_idOficina = ID_oficina, Tarefa = 'OFICINA'
        WHERE idPrisioneiro = ID_prisioneiro;
        
			IF (vErro = 1) THEN
			ROLLBACK;
			SELECT( 'Transação abortada') AS MSG;
			LEAVE Atualizar;
			END IF;
            
        ELSE IF (ID_oficina IS NULL) THEN
		UPDATE Prisioneiro
        SET Oficina_idOficina = ID_oficina, Tarefa = 'FOLGA'
        WHERE idPrisioneiro = ID_prisioneiro;
        
			IF (vErro = 1) THEN
			ROLLBACK;
			SELECT( 'Transação abortada') AS MSG;
			LEAVE Atualizar;
			END IF;
            
		ELSE 
		SELECT('Abortando transação - Oficina Inexistente') AS MSG;
		LEAVE Atualizar;
        END IF;
        END IF;

        ELSE 	
		SELECT( 'Abortando transação - Prisioneiro Inexistente') AS MSG;
		LEAVE Atualizar;
        END IF;
COMMIT;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE AtualizarReclusos(IN id_cadeia INT) 
Atualizar:BEGIN
	DECLARE conditionChecker BOOL DEFAULT FALSE;
	DECLARE done BOOL DEFAULT FALSE;
    DECLARE prisioneiro_id INT;
    DECLARE cur CURSOR FOR SELECT idPrisioneiro FROM Prisioneiro;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    open cur;
START TRANSACTION;
	  read_loop: LOOP
        FETCH cur INTO prisioneiro_id;
        
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        CALL DiminuiPena(prisioneiro_id, conditionChecker);
        IF (NOT conditionChecker) THEN
        ROLLBACK;
        SELECT CONCAT('FALHOU NO PRISIONEIRO DE ID ', prisioneiro_id, ' ABORTANDO') as ErrorMSG;
        LEAVE ATUALIZAR;
        END IF;
    END LOOP;
    CLOSE cur;
COMMIT;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE CalcularDespesaCadeia(IN ID_cadeia INT) 
Calculo:BEGIN
    DECLARE Salarios DECIMAL(10,2);
    DECLARE DespesaAlas DECIMAL(10,2);
    DECLARE DespesaPrisioneiros DECIMAL(10,2);
    DECLARE DespesaOficinas DECIMAL(10,2);
    DECLARE vErro INT DEFAULT 0;
    
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET vErro = 1;
    
    START TRANSACTION;
    
    IF (ID_cadeia IS NOT NULL AND ((SELECT EXISTS (SELECT 1 FROM Cadeia WHERE ID = ID_cadeia)) = 1)) THEN
        SELECT SUM(Salario) INTO Salarios FROM Funcionario WHERE Cadeia_ID = ID_cadeia;
        
        IF (vErro = 1) THEN
            SELECT 'Transação abortada - Falha no cálculo de salários' AS MSG;
            LEAVE Calculo;
        END IF;
        
	SELECT SUM(DespesaMensal) INTO DespesaAlas
	FROM (
    SELECT DISTINCT DespesaMensal
    FROM Ala a
    JOIN Cela c ON a.idAla = c.Ala_idAla
    WHERE c.ocupacao > 0
	) AS subquery;

        
        IF (vErro = 1) THEN
            SELECT 'Transação abortada - Falha no cálculo do preço de Alas' AS MSG;
            LEAVE Calculo;
        END IF;
        
        SELECT (ocupacao * DespesaMensalAlimentacaoPorPrisioneiro) INTO DespesaPrisioneiros FROM Cadeia WHERE ID = ID_cadeia;
        
        IF (vErro = 1) THEN
            SELECT 'Transação abortada - Falha no cálculo de despesa de alimentação' AS MSG;
            LEAVE Calculo;
        END IF;
        
        SELECT SUM(o.PrecoProduto) INTO DespesaOficinas FROM Oficina o JOIN Prisioneiro p ON p.Oficina_idOficina = o.idOficina;
        
		IF (vErro = 1) THEN
            SELECT 'Transação abortada - Falha no cálculo de despesa das oficinas' AS MSG;
            LEAVE Calculo;
        END IF;
        
        UPDATE Cadeia
        SET DespesaMensal = Salarios + DespesaAlas + DespesaPrisioneiros + DespesaOficinas
        WHERE ID = ID_cadeia;
        
        IF (vErro = 1) THEN
            ROLLBACK;
            SELECT 'Transação abortada - Falha no update da tabela' AS MSG;
            LEAVE Calculo;
        END IF;
        
        SELECT CONCAT('Alteração efetuada com sucesso, a despesa deste mês é de ', DespesaMensal, ' euros') AS MSG FROM Cadeia WHERE ID = ID_cadeia;
    ELSE
        SELECT ('Cadeia Inexistente') AS MSG;
    END IF;
    
    COMMIT;
    
END $
DELIMITER ;


DELIMITER $
CREATE PROCEDURE AdicionarFuncionario(IN Salario DECIMAL(10,2), IN DataDeNascimento DATE, IN Nome VARCHAR(45), IN Cargo ENUM('DIRETOR', 'SECRETARIO', 'GUARDA', 'RESPONSAVELOFICINA'), IN ALAID INT, IN Cadeia_id INT)
BEGIN

IF ((select exists (select 1 from Cadeia where ID = Cadeia_id)) = 1) THEN
	IF (ALAID IS NULL OR ((select exists (select 1 from Ala where idAla = ALAID)) = 1)) THEN
		INSERT INTO Funcionario (Salario, DataDeNascimento, Nome, Cargo, Ala_idAla1, Cadeia_ID)
        VALUES(Salario, DataDeNascimento, Nome, Cargo, ALAID, Cadeia_id);
        SELECT 'Adicionado com sucesso' AS MSG;
	ELSE SELECT 'Ala Inexistente' AS MSG;
    END IF;
ElSE SELECT 'Cadeia Inexistente' AS mensagem;
END IF;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE RemoverFuncionario(IN ID INT)
BEGIN

IF ((select exists (select 1 from Funcionario where idFuncionario = ID)) = 1) THEN
		DELETE FROM Funcionario
        WHERE idFuncionario = ID;
        SELECT 'Remoção bem sucedida' AS mensagem;
	ElSE SELECT 'Funcionário inexistente' AS mensagem;
    END IF;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE TrocarResponsavelOficina(IN ID_funcionario INT, IN ID_oficina INT) 
Atualizar:BEGIN
    DECLARE aux  ENUM('DIRETOR', 'SECRETARIO', 'GUARDA', 'RESPONSAVELOFICINA');

		IF ((ID_funcionario IS NOT NULL) AND ((select exists (SELECT 1 FROM Funcionario WHERE idFuncionario = ID_funcionario)) = 1)) THEN
        SELECT Cargo INTO aux FROM Funcionario  WHERE idFuncionario = ID_funcionario;
        IF(aux != 'RESPONSAVELOFICINA') THEN 
        	SELECT( 'Funcionário não é elegível para este cargo') AS MSG;
			LEAVE Atualizar;
        ELSE
           IF (ID_oficina IS NOT NULL AND ((select exists (select 1 from Oficina where idOficina = ID_oficina)) = 1)) THEN
        UPDATE Oficina
        SET Funcionario_idFuncionario1 = ID_funcionario
        WHERE idOficina = ID_oficina;
        
			SELECT 'Troca realizada com sucesso' AS MSG;
		ELSE 
		SELECT('Abortando transação - Oficina Inexistente') AS MSG;
		LEAVE Atualizar;
        END IF;
        
        END IF;
        ELSE 	
		SELECT( 'Abortando transação - Funcionario Inexistente') AS MSG;
		LEAVE Atualizar;
        END IF;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE TrocarAlaGuarda(IN ID_funcionario INT, IN ID_ala INT) 
Trocar:BEGIN
    DECLARE aux  ENUM('DIRETOR', 'SECRETARIO', 'GUARDA', 'RESPONSAVELOFICINA');

		IF ((ID_funcionario IS NOT NULL) AND ((select exists (SELECT 1 FROM Funcionario WHERE idFuncionario = ID_funcionario)) = 1)) THEN
        SELECT Cargo INTO aux FROM Funcionario  WHERE idFuncionario = ID_funcionario;
        IF(aux != 'GUARDA') THEN 
        	SELECT( 'Funcionário não é elegível para este cargo') AS MSG;
			LEAVE Trocar;
        ELSE
           IF (ID_ala IS NOT NULL AND ((select exists (select 1 from Ala where idAla = ID_ala)) = 1)) THEN
        UPDATE Funcionario
        SET Ala_idAla1 = ID_ala
        WHERE idFuncionario = ID_funcionario;
        
			SELECT 'Troca realizada com sucesso' AS MSG;
		ELSE 
		SELECT('Abortando transação - Ala Inexistente') AS MSG;
		LEAVE Trocar;
        END IF;
        
        END IF;
        ELSE 	
		SELECT( 'Abortando transação - Funcionario Inexistente') AS MSG;
		LEAVE Trocar;
        END IF;
END $
DELIMITER ;

DELIMITER $
CREATE PROCEDURE TrocarVisitas(IN ID_Prisioneiro INT, IN Permissao BOOL) 
Trocar:BEGIN
	DECLARE aux INT;
		IF ((ID_Prisioneiro IS NOT NULL) AND ((select exists (SELECT 1 FROM Prisioneiro WHERE idPrisioneiro = ID_Prisioneiro)) = 1)) THEN
        SELECT Cela_idCela INTO aux FROM Prisioneiro  WHERE idPrisioneiro = ID_Prisioneiro;
        SELECT Capacidade INTO aux FROM Cela WHERE idCela = aux;
        IF((aux = 1) AND Permissao) THEN 
        	SELECT( 'Prisioneiro encontra-se na solitária, pelo que não é possível permitir visitas') AS MSG;
			LEAVE Trocar;
        ELSE
        UPDATE Prisioneiro
        SET Visitas = Permissao
        WHERE idPrisioneiro = ID_Prisioneiro;
        
			SELECT 'Troca realizada com sucesso' AS MSG;
        END IF;

        ELSE 	
		SELECT( 'Abortando transação - Prisioneiro Inexistente') AS MSG;
		LEAVE Trocar;
        END IF;
END $
DELIMITER ;



-- CALL RemoverPrisioneiro(19);
-- SET @aux = -1;
-- CALL DiminuiPena(2, @aux);
-- CALL AdicionarPrisioneiro('Herbanario', True, 'Paulo Escovar', 1, 'FOLGA', NULL, '1949-12-01', 1);
SELECT * FROM Prisioneiro;
SELECT * FROM Cela;
SELECT * FROM Funcionario;
SELECT * FROM Cadeia;
SELECT * FROM Oficina;
-- CALL AtualizarReclusos(1);
-- CALL ShowPrisioneirosOrdenadosPorTempoRestante(1);
-- CALL ShowNumPrisioneiros(1);
-- CALL CalcularDespesaCadeia(1);
-- CALL AdicionarFuncionario(12000,'1970-12-23','Calvino Vinagre','DIRETOR',NULL,1);
-- CALL RemoverFuncionario(10);
-- CALL TrocarOficinaPrisioneiro(1,1);
-- CALL TrocarResponsavelOficina(3,2);
-- CALL TrocarAlaGuarda(4, 1);
-- CALL TrocarVisitas(7, FALSE);