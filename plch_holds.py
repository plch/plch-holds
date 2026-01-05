# 2019-06-19
# plch holds explorer exporter
# 
# this will export excel workbooks to the specified directory, and then will
# email the list of recipients with the attachement of the workbook for the 
# report in question
# 
# see the config.ini.sample file for how to set the configurations


import configparser
import sqlite3
import psycopg2
import psycopg2.extras
import os
import sys
from os.path import basename
from datetime import datetime, date
from random import randint
import xlsxwriter
from codecs import open
import smtplib
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from textwrap import dedent
# import pdb

class App:

	#~ the constructor
	def __init__(self):
		#~ the local database connection
		self.sqlite_conn = None
		#~ the remote database connection
		self.pgsql_conn = None

		# here are the queries we're using for this process
		# these files can be found in the same base project folder
		#
		# overall query that creates temp tables for eventual output
		self.temp_tables_sql = 'base_holds_query_temp_tables.sql'

		# 1) system-wide holds output
		self.system_wide_output_sql = 'system_wide_output.sql'

		# 2) ninety-day holds output
		self.ninety_day_output_sql = 'ninety_day_output.sql'

		# 3) holds-no-copies holds output
		self.holds_no_copies_output_sql = 'holds_no_copies_output.sql'

		#~ define our output directory (from the base of this directory)
		self.output_dir = os.getcwd() + "/output"
		if not os.path.exists(self.output_dir):
			os.makedirs(self.output_dir)

		# define the output files:
		self.system_wide_file_wb = self.output_dir + date.today().strftime("/%Y-%m-%d-system_wide_holds.xlsx")
		self.ninety_day_file_wb = self.output_dir + date.today().strftime("/%Y-%m-%d-90_day_holds.xlsx")
		self.holds_no_copies_file_wb = self.output_dir + date.today().strftime("/%Y-%m-%d-holds_no_copies.xlsx")

		# open the config file, and parse the options into local vars
		self.config = configparser.ConfigParser(allow_no_value=True)
		self.config.read('config.ini')
		self.db_connection_string = self.config['db']['connection_string']
		self.local_db_connection_string = self.config['local_db']['connection_string']
		self.itersize = int(self.config['db']['itersize'])

		# open the database connections
		self.open_db_connections()

		# create the table if it doesn't exist
		self.create_local_table()

		# create the temp tables on the sierra-db server that we'll be
		# using for later queries
		self.query_create_temp_tables()

		# create the system wide holds output (excel workbook)
		self.create_system_wide_wb()

		# create the 90 day holds output (excel workbook)
		self.create_90_day_wb()

		# crete the holds no copies output (excel workbook)
		self.create_holds_no_copies_wb()


	#~ the destructor
	def __del__(self):
		self.close_db_connections()
		print("done.")


	def rand_int(self, length):
		#~ simple random number generator for our named cursor
		return randint(10**(length-1), (10**length)-1)


	def open_db_connections(self):
		#~ connect to the sierra postgresql server
		try:
			self.pgsql_conn = psycopg2.connect(self.db_connection_string)

		except psycopg2.Error as e:
			print("unable to connect to sierra database: %s" % e)

		#~ connect to the local sqlite database
		try:
			self.sqlite_conn = sqlite3.connect(self.local_db_connection_string)
		except sqlite3.Error as e:
			print("unable to connect to local database: %s" % e)


	def close_db_connections(self):
		print("closing database connections...")
		if self.pgsql_conn:
			if hasattr(self.pgsql_conn, 'close'):
				print("closing pgsql_conn")
				self.pgsql_conn.close()

			self.pgsql_conn = None

		if self.sqlite_conn:
			if hasattr(self.sqlite_conn, 'commit'):
				print("commiting pending transactions to sqlite db...")
				self.sqlite_conn.commit()

			if hasattr(self.sqlite_conn, 'close'):
				print("closing sqlite_conn")
				self.sqlite_conn.close()

			self.sqlite_conn = None


	def create_local_table(self):
		# TODO implement some sort of local storage that's not just excel file output
		pass


	def query_create_temp_tables(self):
		#~ create the cursor, and execute the sql to produce the temp
		#~ tables on the sierra-db from the external sql file
		#~ self.temp_tables_sql
		sql_string = open(self.temp_tables_sql, mode='r', encoding='utf-8-sig').read()

		try:
			with self.pgsql_conn as conn:
				with conn.cursor() as cursor:
					cursor.execute(sql_string)

		except psycopg2.Error as e:
			print("psycopg2 Error: {}".format(e))

		#~ cursor.close()
		cursor = None
		conn = None


	def gen_sierra_data(self, sql, sql_is_file=True):
		try:
			#~ https://stackoverflow.com/questions/47705183/how-to-read-a-sql-file-with-python-with-proper-character-encoding
			if sql_is_file==True:
				sql_string = open(sql, mode='r', encoding='utf-8-sig').read()
			else:
				pass
				#~ TODO
				#~ maybe think about encoding the string utf-8 as well?

			generator_cursor = "gen_cur" + str(self.rand_int(10))
			cursor = self.pgsql_conn.cursor(name=generator_cursor, cursor_factory=psycopg2.extras.DictCursor)
			cursor.itersize = self.itersize

			cursor.execute(sql_string)

			#~ fetch and yield self.itersize number of rows per round
			rows = None
			while True:
				rows = cursor.fetchmany(self.itersize)
				if not rows:
					break

				for row in rows:
					# do something with row
					yield row

			cursor.close()
			cursor = None

		except psycopg2.Error as e:
			print("psycopg2 Error: {}".format(e))


	# create the workbook for the system wide holds
	def create_system_wide_wb(self):

		wb = xlsxwriter.Workbook(self.system_wide_file_wb)
    
		ws_bib_level = wb.add_worksheet(
			date.today().strftime("%Y-%m-%d")
		)

		cell_format_bold_center = wb.add_format({'bold': True, 'align': 'center'})
		cell_format_decimal = wb.add_format({'num_format': '0.00', 'align': 'center'})
		cell_format_number = wb.add_format({'align': 'center'})
		cell_format_date = wb.add_format({'num_format': 'yyyy-mm-dd'})
		# cell_format_callnumber = wb.add_format({'font_name': 'Courier New'})

		ws_bib_level.set_row(0, 25, cell_format_bold_center)

		# set bib_level worksheet columns
		ws_bib_level.set_column('A:A', 10) # "bib_num"
		ws_bib_level.set_column('B:B', 8) # "pub_year"
		ws_bib_level.set_column('C:C', 11, cell_format_date) # "cat_date"
		ws_bib_level.set_column('D:D', 10) # "media_type"
		ws_bib_level.set_column('E:E', 30) # "title"
		ws_bib_level.set_column('F:F', 25) # "call_number"
		ws_bib_level.set_column('G:G', 12) # "vol"
		ws_bib_level.set_column('H:H', 14, cell_format_number) # "active_holds"
		ws_bib_level.set_column('I:I', 14, cell_format_number) # "active_copies"
		ws_bib_level.set_column('J:J', 14, cell_format_number) # "copies_on_order"
		ws_bib_level.set_column('K:K', 14, cell_format_decimal) # "holds_to_copies"

		ws_bib_level.freeze_panes(1, 0)

		#~ set the column names for the spreadsheet
		ws_bib_level.write_row(0, 0,
			(
				"bib number",
				"year\npublished",
				"date\ncataloged",
				"media\ntype(s)",
				"title",
				"call number",
				"volume",
				"active holds",
				"active copies",
				"copies on order",
				"ratio"
		))

		row_counter=1

		for row in self.gen_sierra_data(self.system_wide_output_sql):
			#~ debug
			#~ print(row_counter, end=": ")
			#~ print(row)

			# debug
			# pdb.set_trace()

			ws_bib_level.write_row(row_counter, 0,
				(
					row['bib_num'],
					row['pub_year'],
					row['cat_date'],
					row['media_type'],
					row['title'],
					row['call_number'],
					row['vol'],
					row['count_active_holds'],
					row['count_active_copies'],
					row['count_copies_on_order'],
					float(format(row['ratio_holds_to_copies'], '.2f'))
			))
			row_counter+=1


		"""
		/bib_level
		"""

		# debug
		# add additional blocks like the one above to output to ws_bib_level_all
		# and ws_vol_level_all

		wb.close()


	def create_90_day_wb(self):
		wb = xlsxwriter.Workbook(self.ninety_day_file_wb)
		ws_90_day = wb.add_worksheet("90_day_holds")

		cell_format_bold = wb.add_format({'bold': True})
		#cell_format_decimal = wb.add_format({'num_format': '0.00'})
		cell_format_date = wb.add_format({'num_format': 'yyyy-mm-dd'})

		ws_90_day.set_row(0, None, cell_format_bold)

		# set worksheet columns
		ws_90_day.set_column('A:A', 10) # "bib_num"
		ws_90_day.set_column('B:B', 8) # "vol"
		ws_90_day.set_column('C:C', 10) # "pub_year"
		ws_90_day.set_column('D:D', 11, cell_format_date) # "cat_date"
		ws_90_day.set_column('E:E', 10) # "media_type"
		ws_90_day.set_column('F:F', 30) # "title"
		ws_90_day.set_column('G:G', 25) # "call_number"
		ws_90_day.set_column('H:H', 14) # "over_90_not_os"
		ws_90_day.set_column('I:I', 14) # "over_90_os"
		ws_90_day.set_column('J:J', 14) # "count_active_holds"
		ws_90_day.set_column('K:K', 14) # "count_active_copies"
		ws_90_day.set_column('L:L', 14) # "count_copies_on_order"

		ws_90_day.freeze_panes(1, 0)

		ws_90_day.write_row(0, 0,
		(
			"bib_num",
			"vol",
			"pub_year",
			"cat_date",
			"media_type",
			"title",
			"call_number",
			"over_90_not_os",
			"over_90_os",
			"active_holds",
			"active_copies",
			"copies_on_order"
	  ))

		row_counter=1
		for row in self.gen_sierra_data(self.ninety_day_output_sql):
			ws_90_day.write_row(row_counter, 0,
				( row['bib_num'],
					row['vol'],
					row['pub_year'],
					row['cat_date'],
					row['media_type'],
					row['title'],
					row['call_number'],
					row['over_90_not_os'],
					row['over_90_os'],
					row['count_active_holds'],
					row['count_active_copies'],
					row['count_copies_on_order']
				)
			)
			row_counter+=1

		wb.close()


	def create_holds_no_copies_wb(self):
		wb = xlsxwriter.Workbook(self.holds_no_copies_file_wb)

		# add a generic property
		cell_format_none = wb.add_format(properties=None)

		cell_format_bold = wb.add_format({'bold': True})
		#cell_format_decimal = wb.add_format({'num_format': '0.00'})
		cell_format_date = wb.add_format({'num_format': 'yyyy-mm-dd'})

		# create the worksheets dictionary so we can
		# NOTE: these should match what is being generated from the SQL 
		# (with the exception of "all")
		worksheets = {
			'all': wb.add_worksheet(name="all"),
			'other': wb.add_worksheet(name="other"),
			'out': wb.add_worksheet(name="OUT"),
			'pop': wb.add_worksheet(name="POP"),
			'irf': wb.add_worksheet(name="IRF"),
			'tee': wb.add_worksheet(name="TEE"),
			'clc': wb.add_worksheet(name="CLC"),
			'gen': wb.add_worksheet(name="GEN"),
			'mag': wb.add_worksheet(name="MAG")
		}

		# for key, worksheet in worksheets.items():
		for key, worksheet in worksheets.items():
			# bold the first row
			worksheet.set_row(row=0, height=30, cell_format=cell_format_bold)

			# set worksheet columns
			worksheet.set_column('A:A', 10, cell_format_none)  # "bib record\nnumber"
			worksheet.set_column('B:B', 8, cell_format_none)   # "year\npublished",
			worksheet.set_column('C:C', 10, cell_format_date)  # "date\ncataloged"
			worksheet.set_column('D:D', 10, cell_format_date)  # "matterial\ntype"
			worksheet.set_column('E:E', 30, cell_format_none)  # "title"
			worksheet.set_column('F:F', 25, cell_format_none)  # "call\nnumber"
			worksheet.set_column('G:G', 8, cell_format_none)   # "vol"
			worksheet.set_column('H:H', 12, cell_format_none)  # "count active\nholds"
			worksheet.set_column('I:I', 12, cell_format_date)  # "oldest\n hold date"
			worksheet.set_column('J:J', 12, cell_format_date)  # "newest\n hold date"
			worksheet.set_column('K:K', 14, cell_format_none)  # "bib\nlocations"
			worksheet.set_column('L:L', 14, cell_format_none)  # "isbn"

			worksheet.freeze_panes(1, 0)

			worksheet.write_row(0, 0, (
				"bib record\nnumber",
				"year\npublished",
				"date\ncataloged",
				"material\ntype",
				"title\n",
				"call\nnumber",
				"vol\n",
				"count active\nholds",
				"oldest hold\ndate",
				"newest hold\ndate",
				"bib\nlocations",
				"isbn\n"
				)
			)

			# row counters for the sheets
			row_counters = {
				'all': 1,
				'other': 1,
				'out': 1,
				'pop': 1,
				'irf': 1,
				'tee': 1,
				'clc': 1,
				'gen': 1,
				'mag': 1
			}

			for row in self.gen_sierra_data(self.holds_no_copies_output_sql):
					# output to the all sheet...
					worksheets['all'].write_row(row_counters['all'], 0, (
						row['bib_record_num'], #"bib record\nnumber",
						row['publish_year'], #"year\npublished",
						row['cataloging_date'], #"date\ncataloged",
						row['mat_type'], #"material\ntype",
						row['best_title'], #"title\n",
						row['call_number'], #"call\nnumber",
						row['volume_statement'], #"vol\n",
						row['count_active_holds'], #"count active\nholds",
						row['oldest_hold_date'], #"oldest hold\ndate",
						row['newest_hold_date'], #"newest hold\ndate",
						row['bib_locations'], #"bib\nlocations",
						row['isbn'] #"isbn\n"
						)
					)
					row_counters['all'] += 1

					# write where the row should land (from the column 
					# 'sort_to_sheet)...
					worksheets[(row['sort_to_sheet'])].write_row(row_counters[(row['sort_to_sheet'])], 0, (
						row['bib_record_num'], #"bib record\nnumber",
						row['publish_year'], #"year\npublished",
						row['cataloging_date'], #"date\ncataloged",
						row['mat_type'], #"material\ntype",
						row['best_title'], #"title\n",
						row['call_number'], #"call\nnumber",
						row['volume_statement'], #"vol\n",
						row['count_active_holds'], #"count active\nholds",
						row['oldest_hold_date'], #"oldest hold\ndate",
						row['newest_hold_date'], #"newest hold\ndate",
						row['bib_locations'], #"bib\nlocations",
						row['isbn'] #"isbn\n"
						)
					)
					row_counters[(row['sort_to_sheet'])] += 1

		wb.close()


	def mail_report(self, mail_subject, mail_from, mail_to, mail_body, file_name):
		msg = MIMEMultipart()
		msg['Subject'] = str(mail_subject)
		msg['From'] = str(mail_from)
		msg['To'] = str(mail_to)
		msg.attach(MIMEText(mail_body))
		# do we need this?
		# msg['To'] = config['email']['email_to']
		# msg.attach(MIMEText('System-Wide Holds Report: see attached'))

		with open(file_name, 'rb') as open_file:
			part = MIMEApplication(
				open_file.read(),
				Name=basename(file_name)
			)

		part['Content-Disposition'] = 'attachment; filename="{}"'.format(basename(file_name))
		msg.attach(part)

		mailserver = smtplib.SMTP(self.config['email']['smtp_host'], 587)
		# identify ourselves to smtp client
		mailserver.ehlo()
		# secure our email with tls encryption
		mailserver.starttls()
		# re-identify ourselves as an encrypted connection
		mailserver.ehlo()
		mailserver.login(self.config['email']['smtp_username'], self.config['email']['smtp_password'])
		mailserver.sendmail(mail_from,
			# sendmail expects recipients as a list
			# [email.strip(' ') for email in config['email']['email_to'].split(',')],
			[email.strip(' ') for email in mail_to.split(',')],
			msg.as_string()
		)

		mailserver.quit()
		mailserver = None


if __name__ == "__main__":
	start_time = datetime.now()
	print('starting import at: \t\t{}'.format(start_time))

	# create our class, and run our queries
	app = App()

	# conditionally send email based on which report we want to generate:
	# possible options / reports
	arglist = list(['system-wide', 'ninety-day', 'holds-no-copies'])

	def print_arg_error():
		# no args, do testing
		msg = """
		Error: argument not correct or missing.
		Valid arguments below: 
		"""
		print(dedent(msg))
		print(*arglist, sep="\n")

	try:
		if sys.argv[1] in arglist:
			# found argument in list ...
			if sys.argv[1] == 'system-wide':
				print(sys.argv[1])
				# system wide report
				app.mail_report(
					# 'System Wide Hold Report', 
					app.config['email_system_wide']['email_subject'],
					app.config['email_system_wide']['email_from'], 
					app.config['email_system_wide']['email_to'],
					'System Wide Holds: See attached',
					app.system_wide_file_wb
				)

			elif sys.argv[1] == 'ninety-day':
				print(sys.argv[1])
				# ninety day report
				app.mail_report(
					app.config['email_ninety_day']['email_subject'],
					app.config['email_ninety_day']['email_from'],
					app.config['email_ninety_day']['email_to'],
					app.config.get('email_ninety_day', 'email_body'),
					app.ninety_day_file_wb
				)

			elif sys.argv[1] == 'holds-no-copies':
				print(sys.argv[1])
				# holds no copies report
				app.mail_report(
					app.config['email_holds_no_copies']['email_subject'],
					app.config['email_holds_no_copies']['email_from'],
					app.config['email_holds_no_copies']['email_to'],
					'Holds No Copies Report: See attached',
					app.holds_no_copies_file_wb
				)
		else:
			print_arg_error()

	except Exception as e:
		import traceback
		print("\n--- ERROR ---")
		traceback.print_exc()
		print("--- END ERROR ---\n")
		print_arg_error()

	end_time = datetime.now()
	print('finished import at: \t\t{}'.format(end_time))
	print('total import time: \t\t{}'.format(end_time - start_time))
