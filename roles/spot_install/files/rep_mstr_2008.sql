--********************************************************************************
/*             SeaChange International Inc.'s REP_MSTR_2008.SQL script          */
--********************************************************************************
/* $Log: rep_mstr_2008.sql $                                                    */
/* 05/11/10 HL Initial version							*/
/* 05/18/10 SPT-2124 HL Moved alert                                             */
/*          "Replication: Subscriber has failed data validation"                */
/*          from genmpeg_2008.sql to prevent failure in genmpeg_2008.sql due to */
/*          the fact that alert was created after distributor is set up here    */
/* 07/16/10 HL fix SPT-2188, not to grant publication access to SeaChangSupport */
/* 07/27/11 HL Change the immediate_sync from 1 to 0 for proper cleaning up of  */
/*          replicated transactions in distribution database. change the minimum*/
/*          retention period for distribution db to 0                           */
--********************************************************************************
Print 'REP_MSTR_2008.SQL -- START'
go
use mpeg
go
SET NOCOUNT ON
go
SET QUOTED_IDENTIFIER ON
go
Print ' '
Print '**** CDCI WORK - START'
go
--Create temp table for the version
if not exists (SELECT 1 FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA='dbo' AND TABLE_NAME='TMPSCRIPTVER')
   begin
	PRINT '   Creating Table:  TMPSCRIPTVER'
	create table dbo.TMPSCRIPTVER (
	  SCRIPTVER varchar(32) not null)
   end
go
if not exists (SELECT 1 from INFORMATION_SCHEMA.TABLE_CONSTRAINTS
		WHERE TABLE_NAME='TMPSCRIPTVER' AND CONSTRAINT_NAME='PK_TMPSCRIPTVER')
   begin
	print '     Creating Primary Key'
	Alter table dbo.TMPSCRIPTVER add
		constraint PK_TMPSCRIPTVER  PRIMARY KEY CLUSTERED
		(SCRIPTVER) WITH FILLFACTOR=100
   end
go
if exists ( select 1 from TMPSCRIPTVER )
   begin
	delete from TMPSCRIPTVER
   end
go
insert into TMPSCRIPTVER  values ('CDCI Unified Schema V5.4')
go
if exists ( select 1 from CDCI_VERSION where COMPONENT = 'Replication Master (rep_mstr)')
   begin
		delete CDCI_VERSION where COMPONENT = 'Replication Master (rep_mstr)'
   end
go
insert into CDCI_VERSION select 'Replication Master (rep_mstr)', SCRIPTVER+', incomplete',0 from TMPSCRIPTVER
go
print '     Log runtime in CDCI_CONFIGLOG'
insert into CDCI_CONFIGLOG
  select getdate(), host_name(), suser_sname(),
          'Added standalone components with repl_mstr_2008.sql, version ' + SCRIPTVER
   from TMPSCRIPTVER
go
update CDCI_VERSION
   set    REVSTATUS = 'Replication Master'
 where  COMPONENT = 'Database Type'
go
Print '**** CDCI WORK - FINISHED'
go
Print ' '
--************************************************************************************************************
Print '**** Bandwidth license triggers - STARTED'
go

if object_id('setup_machine_insert') is not NULL
   begin
	drop trigger dbo.setup_machine_insert
   end
go
print '     Creating setup_machine_insert'
go
create trigger dbo.setup_machine_insert
on SETUP_MACHINE
FOR INSERT
as
begin

declare @computer_name	varchar(64)
declare @system_type	int
declare @system_function	int
declare @tsi_subtype	int
declare @rc		int

select @system_type = TYPE from SYSTEM_TYPES_TEXT where NAME = 'TSI Inserter'
Declare setup_machine_cur cursor for
select MACHINE_NAME, SYSTEM_FUNCTION from inserted where SYSTEM_TYPE = @system_type

open setup_machine_cur

Fetch next from setup_machine_cur
	into @computer_name,@system_function

While @@FETCH_STATUS = 0
   begin
-- 	select @computer_name as 'COMPUTER_NAME', @system_function as 'SYSTEM_FUNCTION'
 	select @tsi_subtype = TSI_SUBTYPE from TSI_SUBTYPE_TEXT where SYSTEM_FUNCTION = @system_function
	if @tsi_subtype is not null
	begin
		-- @rc will be zero, check is not required
		exec @rc = cdci_set_subtype @computer_name, @tsi_subtype, 1
	end

	Fetch next from setup_machine_cur
		into @computer_name,@system_function
   end

close setup_machine_cur
deallocate setup_machine_cur

end
go


if object_id('setup_machine_update') is not NULL
   begin
	drop trigger dbo.setup_machine_update
   end
go
print '     Creating setup_machine_update'
go
create trigger dbo.setup_machine_update
on SETUP_MACHINE
for update
as
begin

declare @computer_name	varchar(64)
declare @system_type	int
declare @system_function	int
declare @tsi_subtype	int
declare @old_system_function	int
declare @rc	int

if update(SYSTEM_FUNCTION)
begin
	select @system_type = TYPE from SYSTEM_TYPES_TEXT where NAME = 'TSI Inserter'
	Declare setup_machine_cur cursor for
	select MACHINE_NAME, SYSTEM_FUNCTION from inserted where SYSTEM_TYPE = @system_type

	open setup_machine_cur

	Fetch next from setup_machine_cur
		into @computer_name,@system_function

	While @@FETCH_STATUS = 0
	   begin
	 	select @tsi_subtype = TSI_SUBTYPE from TSI_SUBTYPE_TEXT where SYSTEM_FUNCTION = @system_function

		IF @tsi_subtype is not NULL
		begin
			exec @rc = cdci_set_subtype @computer_name, @tsi_subtype, 1
		end
		Fetch next from setup_machine_cur
			into @computer_name,@system_function
	   end

	close setup_machine_cur
	deallocate setup_machine_cur
end
end
go

if object_id('setup_network_insert') is not NULL
   begin
	drop trigger dbo.setup_network_insert
   end
go
print '     Creating setup_network_insert'
go
create trigger dbo.setup_network_insert
on SETUP_NETWORK
for insert
as
begin

declare @machine_name	varchar(64)
declare @mac_addr	varchar(64)
declare @rc		int

	select @machine_name = MACHINE_NAME from inserted
	-- call stored procedure, no result set, only return code. otherwise any logic to fire the trigger will receive the result set.
	exec @rc = cdci_bw_validate_lic @machine_name, NULL, 1
end
go

if object_id('setup_network_update') is not NULL
   begin
	drop trigger dbo.setup_network_update
   end
go
print '     Creating setup_network_update'
go
create trigger dbo.setup_network_update
on SETUP_NETWORK
for update
as
begin

declare @machine_name	varchar(64)
declare @mac_addr	varchar(64)
declare @rc		int
	-- Only validate LIC_MAC_ADDR if the MAC_ADDR column is updated
	if update(MAC_ADDR)
	begin
		select @machine_name = MACHINE_NAME from inserted
		-- call stored procedure, no result set, only return code. otherwise any logic to fire the trigger will receive the result set.
		exec @rc = cdci_bw_validate_lic @machine_name, NULL, 1
	end
end
go

if object_id('setup_network_delete') is not NULL
   begin
	drop trigger dbo.setup_network_delete
   end
go
print '     Creating setup_network_delete'
go
create trigger dbo.setup_network_delete
on SETUP_NETWORK
for delete
as
begin

declare @machine_name	varchar(64)
declare @mac_addr	varchar(64)
declare @rc		int
	select @machine_name = MACHINE_NAME from deleted
		-- call stored procedure, no result set, only return code. otherwise any logic to fire the trigger will receive the result set.
	exec @rc = cdci_bw_validate_lic @machine_name, NULL, 1
end
go


Print '**** Bandwidth license triggers - FINISHED'
go


Print '**** REPLICATION CHANGES - START'
go

use master
go
declare @dist_srv	nvarchar(100)
exec sp_helpdistributor @dist_srv OUTPUT
select @dist_srv

if (@dist_srv is NULL)
begin
	Print 'Distributor has not been setup, Adding local distributor'
	set @dist_srv = @@servername
	exec sp_adddistributor @distributor = @dist_srv, @password = N''
	-- Adding the agent profiles
	-- Updating the agent profile defaults
	exec sp_MSupdate_agenttype_default @profile_id = 1
	exec sp_MSupdate_agenttype_default @profile_id = 2
	exec sp_MSupdate_agenttype_default @profile_id = 4
	exec sp_MSupdate_agenttype_default @profile_id = 6
	exec sp_MSupdate_agenttype_default @profile_id = 11
	exec sp_MSupdate_agenttype_default @profile_id = 14

	declare @prof_id	int
	declare @def_prof	bit
	select @prof_id = profile_id, @def_prof = def_profile from msdb..MSagent_profiles where agent_type =3 and profile_name = 'Continue on data consistency errors.'

	if (@def_prof <> 1)
		exec sp_MSupdate_agenttype_default @profile_id = @prof_id

end

if not exists (select 1 from sys.databases where name = 'distribution' and is_distributor = 1)
begin
	Print 'Local Database <distribution> does not exist, Creating distribution database on local database server'
	exec sp_adddistributiondb @database = N'distribution', @data_folder = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data', @data_file = N'distribution.MDF', @data_file_size = 17, @log_folder = N'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Data', @log_file = N'distribution.LDF', @log_file_size = 2, @min_distretention = 0, @max_distretention = 120, @history_retention = 120, @security_mode = 1
end

declare @publisher	nvarchar(100)
select @publisher = name from msdb.dbo.MSdistpublishers
if (@publisher is NULL or @publisher <> @@servername)
begin
	Print 'Publisher does not exist, Creating local database server as publisher'
	declare @working_dir	nvarchar(100)
	set @working_dir = N'\\' + @@SERVERNAME + N'\C_DRIVE\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\ReplData'
	exec sp_adddistpublisher @publisher = @@servername, @distribution_db = N'distribution', @security_mode = 1, @working_directory = @working_dir, @trusted = N'false', @thirdparty_flag = 0, @publisher_type = N'MSSQLSERVER'
end
go

if not exists (select 1 from sys.databases where name = 'mpeg' and is_published = 1)
begin
	PRINT '     Enabling mpeg database to be published'
	exec sp_replicationdboption @dbname = N'mpeg', @optname = N'publish', @value = N'true'
end
go

use mpeg
go
print '     Add uniqueidentifier column to each replicated transaction table'
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='IU' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.IU 					add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='IU_TONE_SERVER_MAP' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.IU_TONE_SERVER_MAP 	add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='INTERCONNECT_SOURCE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.INTERCONNECT_SOURCE add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='MAP_LINKS' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.MAP_LINKS			add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='NTP' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.NTP					add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='PATTERN' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.PATTERN				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='SITE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.SITE				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='SITE_MACHINE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.SITE_MACHINE		add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='SPLICER' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.SPLICER				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='SPLICER_PORT' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.SPLICER_PORT		add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TB_PATH' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TB_PATH				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TB_SERVICE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TB_SERVICE			add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TM_PATH' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TM_PATH				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TONE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TONE				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TONE_SERVER' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TONE_SERVER			add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='VIDEO' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.VIDEO				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='VIDEO_X_COMPUTER' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.VIDEO_X_COMPUTER	add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='ZONE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.ZONE				add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='ZONE_PRIORITY' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.ZONE_PRIORITY		add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TSI_SUBTYPE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TSI_SUBTYPE			add msrepl_tran_version uniqueidentifier not null default newid()
end
if not exists (select * from INFORMATION_SCHEMA.COLUMNS where TABLE_SCHEMA='dbo' and TABLE_NAME ='TSI_BW_LICENSE' and COLUMN_NAME = 'msrepl_tran_version')
begin
		alter table dbo.TSI_BW_LICENSE		add msrepl_tran_version uniqueidentifier not null default newid()
end
go

declare @exists_ind int
set @exists_ind = 0
-- does the publication already exist?
exec sp_helppublication 	@publication = 'mpeg Master Replication', @found = @exists_ind OUTPUT
select @exists_ind

if (@exists_ind = 0 or 	@exists_ind is NULL)
   begin
		-- Adding the transactional publication
		PRINT '     Adding publication'
		----exec [mpeg].sys.sp_addlogreader_agent @publisher_security_mode = 0, @publisher_login = N'sa', @job_name = N'W2K8MDB-mpeg-1', @job_login = null, @job_password = null
		----GO
		----exec [mpeg].sys.sp_addqreader_agent @job_name = null, @frompublisher = 1, @job_login = null, @job_password = null
		----GO
		-- Adding the transactional publication
		exec sp_addpublication @publication = N'mpeg Master Replication', @description = N'Transactional publication of mpeg database from Publisher ', @sync_method = N'native', @retention = 0, @allow_push = N'true', @allow_pull = N'false', @allow_anonymous = N'false', @enabled_for_internet = N'false', @snapshot_in_defaultfolder = N'true', @compress_snapshot = N'false', @ftp_port = 21, @ftp_login = N'anonymous', @allow_subscription_copy = N'false', @add_to_active_directory = N'false', @repl_freq = N'continuous', @status = N'active', @independent_agent = N'true', @immediate_sync = N'false', @allow_sync_tran = N'false', @autogen_sync_procs = N'false', @allow_queued_tran = N'false', @allow_dts = N'false', @replicate_ddl = 1, @allow_initialize_from_backup = N'false', @enabled_for_p2p = N'false', @enabled_for_het_sub = N'false'
		--exec sp_addpublication_snapshot @publication = N'mpeg Master Replication', @frequency_type = 4, @frequency_interval = 1, @frequency_relative_interval = 1, @frequency_recurrence_factor = 0, @frequency_subday = 8, @frequency_subday_interval = 1, @active_start_date = 0, @active_end_date = 0, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @snapshot_job_name = N'W2K8MDB-mpeg-mpeg Master Replication-Snapshot', @job_login = null, @job_password = null, @publisher_security_mode = 1


		exec sp_addpublication_snapshot @publication = N'mpeg Master Replication', @frequency_type = 4, @frequency_interval = 1, @frequency_relative_interval = 1, @frequency_recurrence_factor = 0, @frequency_subday = 8, @frequency_subday_interval = 1, @active_start_date = 0, @active_end_date = 0, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @job_login = null, @job_password = null, @publisher_security_mode = 1
		--  @snapshot_job_name = N'mpeg Master Replication'
		declare @db_user		nvarchar(50)
		declare @svc_account	nvarchar(50)
		declare @admin_grp		nvarchar(50)
		--set @db_user = 'sa'
		--set @admin_grp	= 'BUILTIN\Administrators'
		-- SPT-2767 SQL script shouldn't fail if SeaChangeServices or other hard-coded account is removed
		-- set @svc_account = @@SERVERNAME + '\SeaChangeServices'


		--EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key='SOFTWARE\SeaChange\CDCI\CurrentVersion\Services', @value_name='DbmsUser', @value=@db_user OUTPUT
		-- exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = @admin_grp
		--exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = @db_user
		exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = N'NT AUTHORITY\SYSTEM'
		-- exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = @svc_account
		exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = N'NT SERVICE\SQLSERVERAGENT'
		exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = N'NT SERVICE\MSSQLSERVER'
		exec sp_grant_publication_access @publication = N'mpeg Master Replication', @login = N'distributor_admin'

		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'INTERCONNECT_SOURCE', @source_owner = N'dbo', @source_object = N'INTERCONNECT_SOURCE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'INTERCONNECT_SOURCE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'IU', @source_owner = N'dbo', @source_object = N'IU', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'IU', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'IU_TONE_SERVER_MAP', @source_owner = N'dbo', @source_object = N'IU_TONE_SERVER_MAP', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'IU_TONE_SERVER_MAP', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'MAP_LINKS', @source_owner = N'dbo', @source_object = N'MAP_LINKS', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'MAP_LINKS', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'NTP', @source_owner = N'dbo', @source_object = N'NTP', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'NTP', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'PATTERN', @source_owner = N'dbo', @source_object = N'PATTERN', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'PATTERN', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'SITE', @source_owner = N'dbo', @source_object = N'SITE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'SITE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'SITE_MACHINE', @source_owner = N'dbo', @source_object = N'SITE_MACHINE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'SITE_MACHINE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'SPLICER', @source_owner = N'dbo', @source_object = N'SPLICER', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'SPLICER', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'SPLICER_PORT', @source_owner = N'dbo', @source_object = N'SPLICER_PORT', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'SPLICER_PORT', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TB_PATH', @source_owner = N'dbo', @source_object = N'TB_PATH', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TB_PATH', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TB_SERVICE', @source_owner = N'dbo', @source_object = N'TB_SERVICE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TB_SERVICE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TM_PATH', @source_owner = N'dbo', @source_object = N'TM_PATH', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TM_PATH', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TONE', @source_owner = N'dbo', @source_object = N'TONE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TONE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TONE_SERVER', @source_owner = N'dbo', @source_object = N'TONE_SERVER', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TONE_SERVER', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TSI_BW_LICENSE', @source_owner = N'dbo', @source_object = N'TSI_BW_LICENSE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TSI_BW_LICENSE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'TSI_SUBTYPE', @source_owner = N'dbo', @source_object = N'TSI_SUBTYPE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'TSI_SUBTYPE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'VIDEO', @source_owner = N'dbo', @source_object = N'VIDEO', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'VIDEO', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'VIDEO_X_COMPUTER', @source_owner = N'dbo', @source_object = N'VIDEO_X_COMPUTER', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'VIDEO_X_COMPUTER', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'ZONE', @source_owner = N'dbo', @source_object = N'ZONE', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'ZONE', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
		exec sp_addarticle @publication = N'mpeg Master Replication', @article = N'ZONE_PRIORITY', @source_owner = N'dbo', @source_object = N'ZONE_PRIORITY', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'none', @schema_option = 0x000000010203008D, @identityrangemanagementoption = N'none', @destination_table = N'ZONE_PRIORITY', @destination_owner = N'dbo', @status = 16, @vertical_partition = N'false', @ins_cmd = N'SQL', @del_cmd = N'SQL', @upd_cmd = N'SQL'
   end
else
   begin
				PRINT '     Publication already exists : No Action Taken'
   end
go

print ''
print '     Change job step to loop - START'
go
declare @job_id uniqueidentifier
declare @rc		int
set @job_id = null

--select * from msdb..sysjobs where category_id in (10,13)
-- get the first one
select top 1 @job_id=job_id from msdb..sysjobs where category_id in (10,13) order by job_id

while @job_id IS NOT NULL
   begin
		-- Update the last step (step 3) to loop back to step 1 on success (not failure)
		print '        Updating job '+Cast(@job_id as varchar(36))

		exec @rc=msdb..sp_update_jobstep 	@job_id, @step_id=3, @on_success_action =4, @on_success_step_id =1

		-- get the next one or BREAK
		If exists (select top 1 job_id from msdb..sysjobs where category_id in (10,13) and job_id > @job_id order by job_id)
		   begin
				select top 1 @job_id=job_id from msdb..sysjobs where category_id in (10,13) and job_id > @job_id order by job_id
		   end
		else
			set @job_id = NULL
   end
go
print '     Change job step to loop - FINISHED'
go
Print ''
Print '**** UPDATE ALERTS - START'
go
PRINT '     Updating replication validation failure alert.'
go

use msdb
EXEC sp_update_alert
	@name = 'Replication: Subscriber has failed data validation',
	@enabled = 1,
	@job_name = 'Log Validation Error To Event Log'

use mpeg
go
Print '**** UPDATE ALERTS - FINISHED'
go

Print '**** REPLICATION CHANGES - END'
go
Print ''
Print '**** CLEANUP - START'
go
PRINT '     Updating Version on CDCI_VERSION for Replication Client'
update CDCI_VERSION
   set    REVSTATUS = (select SCRIPTVER from TMPSCRIPTVER )
 where  COMPONENT = 'Replication Master (rep_mstr)'
go
Print '**** CLEANUP - FINISHED'
go
Print ''
Print 'REP_MSTR_2008.SQL -- FINISHED'
go
