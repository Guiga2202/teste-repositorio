(
		select 
			receitas.nivel, 
			receitas.cat_integrada, 
			receitas.tipo_unidade, 
			receitas.unidade, 
			receitas.descricao, 
			receitas.coes, 
			date_part('month', receitas.data_hora_entregue) as data_entregue, 
			'C' as credito_debito, 
			round(sum(receitas.valor_entregue+COALESCE(acrescimo,0)),2) as total_entregue,
			'' as classificacao, 
			'' as centro_de_custo, 
			'' as plano_de_conta,
			sum(REPLACE(metragem_entregue,',','.')::NUMERIC) as metragem_entregue,
			receitas.categoria_produto,
			receitas.classe_produto,
			receitas.sub_classe_produto
		from dre_faturamento receitas 
		where data_hora_entregue::date between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
							group by receitas.nivel, 
							receitas.cat_integrada, 
							receitas.tipo_unidade, 
							receitas.unidade, 
							receitas.descricao, 
							receitas.coes, 
							date_part('month', receitas.data_hora_entregue),
							receitas.categoria_produto, 
							receitas.classe_produto, 
							receitas.sub_classe_produto
)
	UNION ALL /* FATURAMENTO DE SERVIÇO */
	(
	Select 		
			('1.3.1') as nivel
			, '' as cat_integrada
			, vendas.tipo_unidade
			, vendas.unidade 
			, regexp_replace(concat(vendas.categoria_produto, '-', vendas.classe_produto, '-', vendas.sub_classe_produto), '[\n\r]+'::text, ''::text, 'g'::text) AS descricao
			, coes.nome AS coes
			, date_part('month', vendas.data_hora_pedido::Date) as data_pedido
			, 'C' as credito_debito
			, ROUND(SUM(vendas.valor_unitario_total_com_desconto::numeric), 2)
			, '' as classificacao 
			, '' as centro_de_custo 
			, '' as plano_de_conta 
			, '0'::NUMERIC as metragem_entregue
			, vendas.categoria_produto
			, vendas.classe_produto
			, vendas.sub_classe_produto
		from pedidos vendas
			LEFT JOIN coes coes ON 
			coes.nome = vendas.coes 
			where tipo_produto = '3' 
			and data_hora_pedido::date between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
			and coes.gerafaturamento = 'SIM'
		group by nivel, cat_integrada, tipo_unidade, unidade, cod_pedido, data_hora_pedido, descricao, coes.nome, nome_cliente, categoria_produto, classe_produto, sub_classe_produto 
	)
	UNION ALL /*CUSTO DE PRODUTO VENDIDO */
	(
		select 
			receitas.nivel, 
			receitas.cat_integrada, 
			receitas.tipo_unidade, 
			receitas.unidade, 
			receitas.descricao, 
			receitas.coes, 
			date_part('month', receitas.data_hora_entregue) as data_entregue, 
			'D' as credito_debito, 
			round(sum(receitas.valor_entregue),2) as total_entregue,
			'' as classificacao, 
			'' as centro_de_custo, 
			'' as plano_de_conta,
			sum(metragem_entregue) as metragem_entregue,
			receitas.categoria_produto,
			receitas.classe_produto,
			receitas.sub_classe_produto
		from dre_custo receitas 
			where data_hora_entregue::date between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
			group by receitas.nivel, 
							receitas.cat_integrada, 
							receitas.tipo_unidade, 
							receitas.unidade, 
							receitas.descricao, 
							receitas.coes, 
							date_part('month', receitas.data_hora_entregue),
							receitas.categoria_produto, 
							receitas.classe_produto, 
							receitas.sub_classe_produto
	) 
	UNION ALL  /* DEVOLUÇÕES DO MÊS*/
	(	select 
		receitas.nivel, 
		receitas.cat_integrada, 
		receitas.tipo_unidade, 
		receitas.unidade, 
		receitas.descricao, 
		receitas.coes, 
		date_part('month', receitas.data_hora_entregue) as data_entregue, 
		'D' as credito_debito, 
		round(sum(receitas.valor_devolvido) - sum(receitas.custo_devolvido),2) as total_devolvido,
		'' as classificacao, 
		'' as centro_de_custo, 
		'' as plano_de_conta,
		sum(metragem_devolvida) as metragem_devolvida,
		receitas.categoria_produto,
		receitas.classe_produto,
		receitas.sub_classe_produto
	from dre_devolucoes receitas 
	where data_devolucao::date between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
		group by receitas.nivel, 
						receitas.cat_integrada, 
						receitas.tipo_unidade, 
						receitas.unidade, 
						receitas.descricao, 
						receitas.coes, 
						date_part('month', receitas.data_hora_entregue),
						receitas.categoria_produto, 
						receitas.classe_produto, 
						receitas.sub_classe_produto
)
UNION ALL /* DESCONTOS EM TITULOS */
(
SELECT '1.6.1'::text AS nivel,
    ''::text AS cat_integrada,
    pag.tipo_unidade,
    pag.unidade,
    concat('Desconto no Titulo do Pedido', ':', pag.cod_pedido) AS descricao,
    ''::text AS coes,
    date_part('month', pag.data_pagamento::DATE) as data_hora_entregue ,
    'D'::text AS credito_debito,
    sum(replace(pag.total_desconto_titulo::text, ','::text, '.'::text)::numeric) AS desconto_titulo,
    ''::text AS classificacao,
    ''::text AS centro_de_custo,
    ''::text AS plano_de_conta,
    '0'::numeric AS metragem_entregue,
    ''::text AS categoria_produto,
    ''::text AS classe_produto,
    ''::text AS sub_classe_produto
   FROM pagamentos_pedidos pag
   where pag.data_pagamento::DATE between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1 and REPLACE(total_desconto_titulo,',','.')::NUMERIC > 0
  GROUP BY pag.unidade, pag.tipo_unidade, pag.cod_pedido, pag.data_pagamento
)
	UNION ALL /* DESPESAS */
(
		 select 
			CONCAT(COALESCE(fin.nivel_centro_custo,'0'),'.',COALESCE(fin.nivel_plano_conta,'000')) as CodConta
			, fin.plano_conta
			, fin.tipo_unidade
			, fin.unidade
			, fin.descricao
			, case fin.classificacao
			 when 'DEVOLUÇÂO DE SALDO' then 6
			 when 'PEDIDO DE COMPRAS' then 4
			 when 'Compra de Mercadoria' then 4
			 when 'PAGAMENTO DE ADIANTAMENTO' then 7
			 WHEN '1. Pessoal' then 1
			 when '2. Ocupação' then 2
			 when '3. Gastos Operacionais' then 3
			 when 'Saidas Não operacionais' then 5
			 else 0
		 end :: text as NivelClassificacao
		, date_part('month',fin.data_pagamento::DATE)
		, 'D' as credito_debito	
		, REPLACE(fin.vlr_pago,',','.')::NUMERIC as vlr_pago
		, fin.classificacao
		, fin.centro_custo
		, fin.plano_conta
		, 0 as metragem
		, '' as categoria_produto
		, '' as classe_produto
		, '' as sub_classe_produto
			from movimentacoes_financeiras fin
		where tipo_de_lancamento = 'Saida'
		and fin.classificacao NOT IN ('PAGAMENTO DE ADIANTAMENTO', 'DEVOLUÇÃO DE SALDO')
		and data_pagamento::DATE between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
	)
UNION ALL 
(
select
'1.7.1' as CodConta,
'' as cat_integrada,
'Tempera' as tipo_unidade,
und as unidade,
'Lucro M² Cobrado x M² Real' as descricao,
'' as coes,
date_part('Month', data_hora_entregue::DATE) as data_hora_entregue,
'C' as Credito_debito,
SUM(lucro) as lucro, 
'' as classificacao, 
'' as centro_de_custo, 
'' as plano_de_conta,
SUM(metragem_entregue) as metragem_entregue ,
'' as categoria,
'' as classe,
'' as subclasse
from lucro_metragem m where data_hora_entregue::DATE between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date - 1 AND current_date
group by und, date_part('Month', data_hora_entregue::DATE)
)
union all 
(
		select 
			receitas.nivel, 
			receitas.cat_integrada, 
			receitas.tipo_unidade, 
			receitas.unidade, 
			receitas.descricao, 
			receitas.coes, 
			date_part('month', receitas.data_hora_entregue) as data_entregue, 
			'D' as credito_debito, 
			round(sum(receitas.valor_entregue),2) as total_entregue,
			'' as classificacao, 
			'' as centro_de_custo, 
			'' as plano_de_conta,
			sum(metragem_entregue) as metragem_entregue,
			receitas.categoria_produto,
			receitas.classe_produto,
			receitas.sub_classe_produto
		from dre_reposicao receitas 
			where data_hora_entregue::date between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
			group by receitas.nivel, 
							receitas.cat_integrada, 
							receitas.tipo_unidade, 
							receitas.unidade, 
							receitas.descricao, 
							receitas.coes, 
							date_part('month', receitas.data_hora_entregue),
							receitas.categoria_produto, 
							receitas.classe_produto, 
							receitas.sub_classe_produto 
)
union all 
(
		select 
			receitas.nivel, 
			receitas.cat_integrada, 
			receitas.tipo_unidade, 
			receitas.unidade, 
			receitas.descricao, 
			receitas.coes, 
			date_part('month', receitas.data_hora_entregue) as data_entregue, 
			'C' as credito_debito, 
			round(sum(receitas.valor_entregue * rebate),2) as total_rebate,
			'' as classificacao, 
			'' as centro_de_custo, 
			'' as plano_de_conta,
			sum(metragem_entregue) as metragem_entregue,
			receitas.categoria_produto,
			receitas.classe_produto,
			receitas.sub_classe_produto
		from dre_rebate receitas 
			where data_hora_entregue::date between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
			group by receitas.nivel, 
							receitas.cat_integrada, 
							receitas.tipo_unidade, 
							receitas.unidade, 
							receitas.descricao, 
							receitas.coes, 
							date_part('month', receitas.data_hora_entregue),
							receitas.categoria_produto, 
							receitas.classe_produto, 
							receitas.sub_classe_produto 
)
union all 
(
select
'1.9.1' as CodConta,
'' as cat_integrada,
egt.tipo_unidade,
egt.unidade,
'Lucro Transferencias' as descricao,
cs.coes,
date_part('Month', data_hora_entregue::DATE) as data_hora_entregue,
'C' as Credito_debito,
SUM(egt.valor_entregue - egt.custo_entregue) as lucro, 
'' as classificacao, 
'' as centro_de_custo, 
'' as plano_de_conta,
SUM(egt.metragem_entregue::numeric) as metragem_entregue ,
'' as categoria,
'' as classe,
'' as subclasse
from entregas_geral_transferencias egt 
left join coes_sistema cs on egt.coes = cs.coes and egt.unidade = cs.unidade 
where data_hora_entregue::DATE between TO_CHAR(NOW()::DATE, 'yyyy-mm-01')::date AND current_date - 1
and cs.tipotitulo <> 'NAO' 
group by 
egt.tipo_unidade,
egt.unidade,
cs.coes,
date_part('Month', data_hora_entregue::DATE)
)
