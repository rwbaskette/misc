/*############################################################################################################
### 
### Copyright (C) 2011 Robert W. Baskette (rwbaskette <at> gmail.com)
### 
### This program is free software; you can redistribute it and/or
### modify it under the terms of the GNU General Public License
### as published by the Free Software Foundation; either version 2
### of the License, or (at your option) any later version.
### 
### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU General Public License for more details.
### 
### You should have received a copy of the GNU General Public License
### along with this program; if not, write to the Free Software
### Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
### 
############################################################################################################*/
-- 
-- Signatures:
--
-- This is a helper procedure. Generates a table of columns and their generated t-sql variables.
-- create function dbo.fnc_codegen_GetTableColTsqlVars(
--	@table nvarchar(255),
--	@table_alias nvarchar(255)
-- )
--
-- The proc genereates CRUD stored procedures for most tables.
-- create proc dbo.prc_codegen_GenerateTableProcs(
-- 	@table nvarchar(4000),
-- 	@tablealias nvarchar(4000),
-- 	@IncludeSoftDeleteBit bit = 0,
-- 	@SoftDeleteBitColumnName nvarchar(1000) = null,
-- 	@SoftDeleteBitColumnActiveValue bit = 0
-- )
go
if object_id('dbo.fnc_codegen_GetTableColTsqlVars') is not null
	drop function dbo.fnc_codegen_GetTableColTsqlVars
go
create function dbo.fnc_codegen_GetTableColTsqlVars( @table nvarchar(255), @table_alias nvarchar(255)) returns table as
return(
	select 
		'[' + c.COLUMN_NAME + ']' [col],
		'[' + c.COLUMN_NAME + ']' + case when c.ORDINAL_POSITION < cnts.col_cnt then ',' else '' end [cold],
		isnull(@table_alias + '.', '') + '[' + c.COLUMN_NAME + ']' + case when c.ORDINAL_POSITION < cnts.col_cnt then ',' else '' end [colda],
		'@' + c.COLUMN_NAME + case when c.ORDINAL_POSITION < cnts.col_cnt then ',' else '' end [var],
		'@' + k.COLUMN_NAME + case when k.ORDINAL_POSITION < cnts.key_cnt then ',' else '' end [var_key],
		case when k.COLUMN_NAME is not null then null 
			else '@' + c.COLUMN_NAME + case when c.ORDINAL_POSITION < cnts.col_cnt then ',' else '' end end [var_nokey],
		case when columnproperty( object_id(c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') = 1 then null 
			else  '@' + c.COLUMN_NAME + case when c.ORDINAL_POSITION < cnts.col_cnt then ',' else '' end end [var_noid],
		'@' + c.COLUMN_NAME + ' ' + c.DATA_TYPE +
		case c.DATA_TYPE 
			when 'varchar' then case when c.CHARACTER_MAXIMUM_LENGTH = -1 then '(max)' else '('+cast( c.CHARACTER_MAXIMUM_LENGTH as varchar(25) )+')' end
			when 'nvarchar' then case when c.CHARACTER_MAXIMUM_LENGTH = -1 then '(max)' else '('+cast( c.CHARACTER_MAXIMUM_LENGTH as varchar(25) )+')' end
			when 'decimal' then '('+cast( c.NUMERIC_PRECISION as varchar(25) )+', '+ cast( c.NUMERIC_SCALE as varchar(25) ) +')'
			else ''
		end + case when c.ORDINAL_POSITION < cnts.col_cnt then ',' else '' end [decl],
		'@' + k.COLUMN_NAME + ' ' + c.DATA_TYPE +
			case c.DATA_TYPE 
			when 'varchar' then case when c.CHARACTER_MAXIMUM_LENGTH = -1 then '(max)' else '('+cast( c.CHARACTER_MAXIMUM_LENGTH as varchar(25) )+')' end
			when 'nvarchar' then case when c.CHARACTER_MAXIMUM_LENGTH = -1 then '(max)' else '('+cast( c.CHARACTER_MAXIMUM_LENGTH as varchar(25) )+')' end
			when 'decimal' then '('+cast( c.NUMERIC_PRECISION as varchar(25) )+', '+ cast( c.NUMERIC_SCALE as varchar(25) ) +')'
			else ''
			end + case when k.ORDINAL_POSITION < cnts.key_cnt then ',' else '' end [decl_key],
			c.DATA_TYPE +
			case c.DATA_TYPE 
				when 'varchar' then case when c.CHARACTER_MAXIMUM_LENGTH = -1 then '(max)' else '('+cast( c.CHARACTER_MAXIMUM_LENGTH as varchar(25) )+')' end
				when 'nvarchar' then case when c.CHARACTER_MAXIMUM_LENGTH = -1 then '(max)' else '('+cast( c.CHARACTER_MAXIMUM_LENGTH as varchar(25) )+')' end
				when 'decimal' then '('+cast( c.NUMERIC_PRECISION as varchar(25) )+', '+ cast( c.NUMERIC_SCALE as varchar(25) ) +')'
				else ''
		end [type],
		'[' + k.COLUMN_NAME + '] = @' + c.COLUMN_NAME + case when k.ORDINAL_POSITION < cnts.key_cnt then ' and ' else '' end [where_key],
		isnull(@table_alias + '.', '') + '[' + k.COLUMN_NAME + '] = @' + c.COLUMN_NAME + case when k.ORDINAL_POSITION < cnts.key_cnt then ' and ' else '' end [where_keya],
		'[' + k.COLUMN_NAME + '] = ' + 
		case when columnproperty( object_id(c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') = 1 then 'scope_identity()'
		else 
			'@' + c.COLUMN_NAME + case when k.ORDINAL_POSITION < cnts.key_cnt then ' and ' else '' end
		end [where_key_ins],
		isnull(@table_alias + '.', '') + '[' + k.COLUMN_NAME + '] = ' + 
		case when columnproperty( object_id(c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') = 1 then 'scope_identity()'
		else
			'@' + c.COLUMN_NAME + case when k.ORDINAL_POSITION < cnts.key_cnt then ' and ' else '' end
		end [where_key_insa],
		case when k.COLUMN_NAME is null then 
			isnull(@table_alias + '.', '') + '[' + c.COLUMN_NAME + '] = @' + c.COLUMN_NAME + case when c.ORDINAL_POSITION < cnts.col_cnt then ' and ' else '' end 
			else '' end [where_nokey],
		case when k.COLUMN_NAME is null then 0 else 1 end as [Iskey],
		columnproperty( object_id(c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity')  [IsIdentity],
		c.ORDINAL_POSITION [col_ordinal], 
		k.ORDINAL_POSITION [key_ordinal], 
		cnts.col_cnt,
		cnts.key_cnt
	from 
		INFORMATION_SCHEMA.COLUMNS c 
		left outer join INFORMATION_SCHEMA.KEY_COLUMN_USAGE k on k.TABLE_NAME = c.TABLE_NAME and k.COLUMN_NAME = c.COLUMN_NAME and
			k.CONSTRAINT_NAME like 'PK_%'
		cross join( 
		-- column and key counts
			select * from
			( select count(*) [col_cnt] from INFORMATION_SCHEMA.COLUMNS c where c.TABLE_NAME = @table ) c
			cross join ( select count(*) [key_cnt] from INFORMATION_SCHEMA.KEY_COLUMN_USAGE k where k.table_name = @table and k.CONSTRAINT_NAME like 'PK_%' ) k
		) cnts
	where
		c.TABLE_NAME = @table
)
go
if object_id('dbo.prc_codegen_GenerateTableProcs') is not null
	drop proc dbo.prc_codegen_GenerateTableProcs
go
create proc dbo.prc_codegen_GenerateTableProcs(
	@table nvarchar(4000),
	@tablealias nvarchar(4000),
	@IncludeSoftDeleteBit bit = 0,
	@SoftDeleteBitColumnName nvarchar(1000) = null,
	@SoftDeleteBitColumnActiveValue bit = 0
) as
begin
	set nocount on

	declare @ta_pre nvarchar(255)
	set @ta_pre = isnull(@tablealias+ '.', '')
	set @tablealias = isnull(@tablealias, '')

	declare @tab char; set @tab = char(9);

	select * into #tmp from dbo.fnc_codegen_GetTableColTsqlVars(@table, @tablealias) order by col_ordinal

	declare @hasid bit; set @hasid = 0
	if exists(select * from #tmp where IsIdentity = 1) set @hasid = 1

	select [text] as ' ' from (
	select 0 [type], 0 [type_sort], '' [text]

	--- Get All
	union select 1 [type], 0 [type_sort], 
	'if object_id(''dbo.prc_'+ @table +'_GetAll'') is not null
	drop proc dbo.prc_'+ @table +'_GetAll
go
create proc dbo.prc_'+ @table +'_GetAll as
begin
	set nocount on;
	select * from dbo.['+ @table +']' +
	case when @IncludeSoftDeleteBit = 1 then 
		' where [' + @SoftDeleteBitColumnName + '] = ' + cast(@SoftDeleteBitColumnActiveValue as nvarchar(1))
	else
		''
	end + ';
end
go'
	union select 1 [type], 0 [type_sort], 
	'if object_id(''dbo.prc_'+ @table +'_GetAll'') is not null
	drop proc dbo.prc_'+ @table +'_GetAll
go
create proc dbo.prc_'+ @table +'_GetAll as
begin
	set nocount on;
	select * from dbo.['+ @table +']' +
	case when @IncludeSoftDeleteBit = 1 then 
		' where [' + @SoftDeleteBitColumnName + '] = ' + cast(@SoftDeleteBitColumnActiveValue as nvarchar(1))
	else
		''
	end + ';
end
go'
	--- Add
	union select 2 [type], 0 [type_sort], 
	'if object_id(''dbo.prc_'+ @table +'_Add'') is not null
	drop proc dbo.prc_'+ @table +'_Add
go
create proc dbo.prc_'+ @table +'_Add('
	union select 2, col_ordinal + 100, @tab + decl from #tmp where IsIdentity = 0
	union select 2, 300, ') as
begin
	set nocount off;'
	union select 2, 301, @tab + 'insert into dbo.'+ @table +'('
	union select 2, 400 + col_ordinal, @tab + @tab + cold from #tmp where isidentity = 0
	union select 2, 700, @tab + ') values('
	union select 2, 800 + col_ordinal, @tab + @tab + var_noid from #tmp where var_noid is not null
	union select 2, 1000, @tab + ')
	select
		'+ @ta_pre +'*
	from
		dbo.' + @table + ' '+ @tablealias +'
	where '
	union select 2, 1001 + col_ordinal,  @tab + @tab + where_key_ins from #tmp where where_key_ins is not null
	union select 2, 1300, 'end
go'
	-- Update
	union select 3 [type], 0 [type_sort], 
	'if object_id(''dbo.prc_'+ @table +'_Update'') is not null
	drop proc dbo.prc_'+ @table +'_Update
go
create proc dbo.prc_'+ @table +'_Update('
	union select 3, col_ordinal + 100, @tab + decl from #tmp
	union select 3, 300, ') as
begin
	set nocount off;
	update
		dbo.' + @table + '
	set'
	union select 3, 400 + col_ordinal, @tab + @tab + col + ' = ' + [var] from #tmp where isidentity = 0
	union select 3, 700, @tab + 'where'
	union select 3, 800 + col_ordinal, @tab + @tab + where_key from #tmp where where_key is not null
	union select 3, 1000, @tab + '
	select
		'+ @ta_pre +'*
	from
		dbo.' + @table + ' '+ @tablealias +'
	where '
	union select 3, 1001 + col_ordinal,  @tab + @tab + where_key from #tmp where where_key is not null
	union select 3, 1300, 'end
go'
	-- Delete
	union select 4 [type], 0 [type_sort], 
	'if object_id(''dbo.prc_'+ @table +'_Delete'') is not null
	drop proc dbo.prc_'+ @table +'_Delete
go
create proc dbo.prc_'+ @table +'_Delete('
	union select 4, col_ordinal + 100, @tab + decl_key from #tmp where decl_key is not null
	union select 4, 300, ') as
begin
	set nocount off;
	delete from
		dbo.' + @table + 
	''
	union select 4, 700, @tab + 'where'
	union select 4, 800 + col_ordinal, @tab + @tab + where_key from #tmp where where_key is not null
	union select 4, 1300, 'end
go'
	--- Get All
	union select 5, 0 [type_sort], 
'if object_id(''dbo.prc_'+ @table +'_GetById'') is not null
	drop proc dbo.prc_'+ @table +'_GetById
go
create proc dbo.prc_'+ @table +'_GetById('
	union select 5, 100 + col_ordinal, @tab + decl_key from #tmp where decl_key is not null
	union select 5, 500, ') as
begin
	set nocount on;
	select
		*
	from
		dbo.['+ @table +']
	where'
	union select 5, 600 + col_ordinal, @tab + @tab + where_key + case when @IncludeSoftDeleteBit = 1 then ' and ' else '' end from #tmp where where_key is not null
	union select 5, 700, @tab + @tab +
		case when @IncludeSoftDeleteBit = 1 then 
			'[' + @SoftDeleteBitColumnName + '] = ' + cast(@SoftDeleteBitColumnActiveValue as nvarchar(1))
		else
			''
		end + ';'
	union select 5, 900, 'end
go'
	) q
	order by 
	[type],
	[type_sort]

	drop table #tmp
end
go