CREATE TABLE `exch_quotes_archive` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `exchange_id` SMALLINT UNSIGNED NOT NULL COMMENT 'идентификатор биржи',
  `bond_id` SMALLINT UNSIGNED NOT NULL COMMENT 'идентификатор облигации',
  `trading_date` DATE NOT NULL COMMENT 'дата торгов на бирже',
  `bid` FLOAT DEFAULT NULL,
  `ask` FLOAT DEFAULT NULL,
  PRIMARY KEY USING BTREE (`id`),
  UNIQUE KEY `exch_quotes_archive_unique_idx` USING BTREE (`trading_date`, `bond_id`, `exchange_id`)
) ENGINE=InnoDB;




CREATE FUNCTION bond_cost ()
    RETURNS JSON
BEGIN
  SET @bid = (RAND() * 2.3 - 0.2);
  IF @bid > 2.03 OR @bid < -0.05 THEN
    SET @bid = null;
  END IF;

  SET @ask = (RAND() * 2.3 - 0.2);
  IF @bid IS NOT NULL THEN -- только одна стоимость может быть null
    IF @ask > 2.03 OR @ask < -0.05 THEN
       SET @ask = null;
    END IF;
  END IF;

  RETURN JSON_OBJECT('bid', @bid, 'ask', @ask);
END;




CREATE PROCEDURE fill_quotes (
        IN `xdate` DATE
    )
    COMMENT 'заполнение таблицы exch_quotes_qrchive'
BEGIN
    SET @date_to = IFNULL(xdate, CURRENT_DATE());
    SET @date_from = DATE_SUB(@date_to, INTERVAL 61 DAY); -- период 62 дня в прошлое от переданной даты
    SET @exchange_list = JSON_ARRAY(1, 4, 72, 99, 250, 399, 502, 600);

    INSERT INTO exch_quotes_archive (exchange_id, bond_id, trading_date, bid, ask)
    WITH RECURSIVE
        -- период
        period(trading_date) AS (
           SELECT @date_from
           UNION ALL
           SELECT
             DATE_ADD(trading_date, INTERVAL 1 DAY)
           FROM period
           WHERE trading_date < @date_to
        ),

        -- идентификаторы облигаций: [1; 200]
        bonds(id) AS (
           SELECT 1
           UNION ALL
           SELECT id + 1
           FROM bonds
           WHERE id < 200
        ),

        -- идентификаторы бирж
        exchanges(id) AS (
            SELECT * FROM JSON_TABLE(
                @exchange_list,
                '$[*]' COLUMNS(
                    id INT PATH '$'
                )
            ) AS j
        )

    SELECT
        dbe.exchange_id,
        dbe.bond_id,
        dbe.trading_date,
        JSON_VALUE(bc.cost, '$.bid' RETURNING FLOAT) AS bid,
        JSON_VALUE(bc.cost, '$.ask' RETURNING FLOAT) AS ask
    FROM (
        -- дата + облигация + биржа
        SELECT
            period.trading_date,
            b.id AS bond_id,
            ex.id AS exchange_id
        FROM period
        JOIN bonds AS b
        JOIN LATERAL (
            SELECT
                id,
                -- for lateral derived
                period.trading_date,
                b.id AS bond_id
            FROM exchanges
            ORDER BY rand()
            LIMIT 7 -- торгуются только на 7 биржах ежедневно
        ) AS ex
        -- кроме субботы и воскресенья
        WHERE DAYOFWEEK(period.trading_date) NOT IN (1,7)
    ) AS dbe
    -- стоимость облигаций
    JOIN LATERAL (
        SELECT
            bond_cost() AS cost,
            dbe.exchange_id  -- for lateral derived
    ) AS bc;
END;

-- Для заполнения таблицы выполнить: 
-- CALL fill_quotes(<дата-или-null>);
