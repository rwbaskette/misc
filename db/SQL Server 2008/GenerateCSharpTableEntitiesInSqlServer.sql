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
-- Helper function that gets the C# Style native CLR type for a given t-sql type.
-- It uses it's own look-up table and is opinionated.
-- dbo.fnc_codegen_GetCsTypeBySqlDataType(
--	@SqlTypeString nvarchar(100), 
--	@Nullable bit 
-- ) returns nvarchar(1000) 
--
-- Generates an optionally IClonable POCO (C#) Entity object.
--  The class contains a static Create method that accepts a System.Data.DataRow 
--   or strongly typed data row to populate it's values.
-- dbo.prc_codegen_GenerateTableEntity( 
-- 	@TableName nvarchar(255), 
-- 	@StronglyTypedRow bit, 
-- 	@IsCloneable bit, 
-- 	@ClassName nvarchar(4000) = null 
-- )
go
if object_id('dbo.fnc_codegen_GetCsTypeBySqlDataType') is not null
	drop function dbo.fnc_codegen_GetCsTypeBySqlDataType
go
create function dbo.fnc_codegen_GetCsTypeBySqlDataType( @SqlTypeString nvarchar(100), @Nullable bit ) returns nvarchar(1000) as
begin
	declare @type nvarchar(1000);
	
	set @type = case @SqlTypeString
		when 'bigint' then 'long'
		when 'binary' then 'byte[]'
		when 'bit' then 'bool'
		when 'char' then 'char'
		when 'date' then 'DateTime'
		when 'datetime' then 'DateTime'
		when 'datetime2' then 'DateTime'
		when 'DATETIMEOFFSET' then 'DateTimeOffset'
		when 'decimal' then 'Decimal'
		when 'float' then 'double'
		when 'image' then 'byte[]'
		when 'int' then 'int'
		when 'money' then 'Decimal'
		when 'nchar' then 'string'
		when 'ntext' then 'string'
		when 'numeric' then 'Decimal'
		when 'nvarchar' then 'string'
		when 'real' then 'Single'
		when 'rowversion' then 'byte[]'
		when 'smalldatetime' then 'DateTime'
		when 'smallint' then 'Int16'
		when 'smallmoney' then 'Decimal'
		when 'sql_variant' then 'object'
		when 'text' then 'string'
		when 'time' then 'TimeSpan'
		when 'timestamp' then 'byte[]'
		when 'tinyint' then 'byte'
		when 'uniqueidentifier' then 'Guid'
		when 'varbinary' then 'byte[]'
		when 'varchar' then 'string'
		when 'xml' then 'string'
		else 'object'
	end;
	
	if @Nullable = 1 and @type <> 'string' and @type <> 'object' and @type not like '%\[]' escape '\'
	begin
		set @type = @type + '?'
	end
	
	return @type;
end
go
if object_id('dbo.prc_codegen_GenerateTableEntity') is not null
	drop proc dbo.prc_codegen_GenerateTableEntity
go
create proc dbo.prc_codegen_GenerateTableEntity( @TableName nvarchar(255), @StronglyTypedRow bit, @IsCloneable bit, @ClassName nvarchar(4000) = null ) as
begin
	set nocount on;
	if ltrim(rtrim(isnull(@ClassName,''))) = ''
		set @ClassName = @TableName +'Entity'
	
	declare @crlf nvarchar(2); set @crlf = char(13) + char(10);
	declare @tab nvarchar(1); set @tab = char(9)
	declare @colcount int
	select @colcount = count(*) from (
			select * from INFORMATION_SCHEMA.COLUMNS
			union select * from INFORMATION_SCHEMA.ROUTINE_COLUMNS
	) q
	where table_name = @TableName

	select
		[Stmt] as [ ]
	from (
		select '[Serializable]' + @crlf + 'public class ' + @ClassName + case when @IsCloneable = 1 then ' : ICloneable ' else ' ' end + '{' [Stmt],
		0 [ORDINAL_POSITION],
		0 [Sort]
	union select
		@tab + 'public ' + 
		dbo.fnc_codegen_GetCsTypeBySqlDataType(DATA_TYPE, case when isnull(IS_NULLABLE,'') = 'YES' then 1 else 0 end ) + ' ' + COLUMN_NAME + ' { get; set; }' [Stmt],
		[ORDINAL_POSITION],
		1 [Sort]
	from
		(
			select * from INFORMATION_SCHEMA.COLUMNS
			union select * from INFORMATION_SCHEMA.ROUTINE_COLUMNS
		) q
	where
		TABLE_NAME = @TableName
	union select
		@crlf + @tab + 'public static '+ @ClassName +' Create( ' + 
			case when @StronglyTypedRow = 1 then
				@TableName +'Row'
			else
				'DataRow'
			end + ' row ) {' + 
			@crlf + @tab + @tab + 'return new '+ @ClassName +'() {',
		0,
		1000
	union select 
		@tab + @tab + @tab + (
				column_name +' = '+ 
				case when @StronglyTypedRow = 1 then
					case when is_nullable ='yes' then
						'(row.IsNull("' + column_name + '") ? null : '+
						'('+ dbo.fnc_codegen_GetCsTypeBySqlDataType(DATA_TYPE, case when isnull(IS_NULLABLE,'') = 'YES' then 1 else 0 end ) +')' + 
						'row.' + column_name + ')'
					else
						'row.'+ column_name
					end
				else
					case when is_nullable ='yes' then
						'('+ dbo.fnc_codegen_GetCsTypeBySqlDataType(DATA_TYPE, case when isnull(IS_NULLABLE,'') = 'YES' then 1 else 0 end ) +')' + 
						'(row.IsNull("' + column_name + '") ? null : (object)row["' + column_name + '"])'
					else
						'('+ dbo.fnc_codegen_GetCsTypeBySqlDataType(DATA_TYPE, case when isnull(IS_NULLABLE,'') = 'YES' then 1 else 0 end ) +')' +
						'row["' + column_name + '"]'
					end
				end + 
				case when ordinal_position < @colcount then ',' else '' end
		) [Stmt],
		ordinal_position,
		ordinal_position + 1 * 1000 [Sort]
	from
		(
			select * from INFORMATION_SCHEMA.COLUMNS
			union select * from INFORMATION_SCHEMA.ROUTINE_COLUMNS
		) q
	where
		table_name = @TableName
	union select @tab + @tab + '};', 0, 2000
	union select @tab + '}', 0, 2001
	union select
		@tab + '#region ICloneable Members' + @crlf +
		@tab + 'public object Clone() {' + @crlf +
		@tab + 'return new '+ @ClassName +'()' + @crlf +
		@tab + '{', 
		0,
		2100
	where
		@IsCloneable = 1
	union select
		@tab + @tab + @tab + COLUMN_NAME + ' = ' + COLUMN_NAME + 
		case when ordinal_position < @colcount then ',' else '' end [Stmt],
		[ORDINAL_POSITION],
		2200 [Sort]
	from (
			select * from INFORMATION_SCHEMA.COLUMNS
			union select * from INFORMATION_SCHEMA.ROUTINE_COLUMNS
	) q
	where
		TABLE_NAME = @TableName and
		@IsCloneable = 1
	union select 
		@tab + @tab + '};' + @crlf +
		@tab + '}' + @crlf +
		@tab + '#endregion',
		0,
		2300
	where
		@IsCloneable = 1
	union
	select
		'}' [Stmt],
		0 [ORDINAL_POSITION],
		10000 [Sort]
	) q
	order by
		[Sort],
		[ORDINAL_POSITION]
end
go