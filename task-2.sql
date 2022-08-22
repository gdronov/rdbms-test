WITH RECURSIVE
    -- период 14 дней
    period(trading_date) AS (
       SELECT DATE_SUB(CURRENT_DATE(), INTERVAL 13 DAY)
       UNION ALL
       SELECT
         DATE_ADD(trading_date, INTERVAL 1 DAY)
       FROM period
       WHERE trading_date < CURRENT_DATE()
    ),

    -- полный список идентификаторов облигаций
    -- этот список нужен, чтобы в результатах на каждую субботу и воскресенье (дни в которых нет торгов
    -- и нет данных) была запись (день + облигация + null-стоимости)
    bonds(id) AS (
        -- тут предполагается, что мы не знаем, что облигации - это заранее известный диапазон [1; 200],
        -- и у нас нету других источников, кроме таблицы exch_quotes_archive, откуда можно их получить
        SELECT DISTINCT bond_id
        FROM exch_quotes_archive
        WHERE trading_date > DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY) -- без BETWEEN, т.к. считаем все даты до сегодня

        -- но если известно заранее и точно про диапазон [1; 200], то можно сделать так
        -- SELECT 1 UNION ALL SELECT id + 1 FROM bonds WHERE id < 200
    )

SELECT
    period.trading_date,
    bonds.id AS bond_id,
    AVG(eqa.bid) AS avg_bid,
    AVG(eqa.ask) AS avg_ask
FROM period
JOIN bonds
LEFT JOIN exch_quotes_archive AS eqa ON (eqa.trading_date = period.trading_date AND eqa.bond_id = bonds.id)
GROUP BY period.trading_date, bonds.id
ORDER BY period.trading_date, bonds.id
