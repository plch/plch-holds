#~ 2018-06-01
#~ plch holds explorer exporter


import configparser
import sqlite3
import psycopg2
import psycopg2.extras
import os
from datetime import datetime, date
from random import randint
import xlsxwriter
from codecs import open
import pdb


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

		# 1) System-wide holds
		self.system_wide_output_sql = 'system_wide_output.sql'

		# 2) 90-day holds
		self.ninety_day_output_sql = 'ninety_day_output.sql'

		# debug
		# we can add these back in if we want to examine more of the holds
		# ...add back in the sheets below if using these
		# self.bib_output_all_sql = 'base_holds_query_bib_output_all.sql'
		# self.vol_output_all_sql = 'base_holds_query_vol_output_all.sql'

		#~ define our output directory (from the base of this directory)
		self.output_dir = os.getcwd() + "/output"
		if not os.path.exists(self.output_dir):
			os.makedirs(self.output_dir)

		self.system_wide_file_wb = self.output_dir + date.today().strftime("/%Y-%m-%d-system_wide_holds.xlsx")

		#~ open the config file, and parse the options into local vars
		config = configparser.ConfigParser()
		config.read('config.ini')
		self.db_connection_string = config['db']['connection_string']
		self.local_db_connection_string = config['local_db']['connection_string']
		self.itersize = int(config['db']['itersize'])

		#~ open the database connections
		#~ TODO:
		#~ if we're going to be using this object as a "long living" one,
		#~ maybe write a test to see if the connections are open, and if
		#~ not, loop connection attemts with a reasonable timeout
		self.open_db_connections()

		#~ create the table if it doesn't exist
		self.create_local_table()

		#~ create the temp tables on the sierra-db server that we'll be
		#~ using for later queries
		self.query_create_temp_tables()

		#~ create the system wide holds output (excel workbook)
		self.create_system_wide_wb()

		# create the 90 day holds output (excel workbook)
		self.create_90_day_wb()


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
		
	  ninety_day_file_wb = self.output_dir + date.today().strftime("/%Y-%m-%d-90_day_holds.xlsx")
	  wb = xlsxwriter.Workbook(ninety_day_file_wb)
	  ws_90_day = wb.add_worksheet("90_day_holds")

	  cell_format_bold_center = wb.add_format({'bold': True, 'align': 'center'})
	  cell_format_number = wb.add_format({'align': 'center'})
	  cell_format_date = wb.add_format({'num_format': 'yyyy-mm-dd'})

	  ws_90_day.set_row(0, 25, cell_format_bold_center)
	  
	  # set worksheet columns
	  ws_90_day.set_column('A:A', 10) # "bib_num"

	  ws_90_day.set_column('B:B', 10) # "pub_year"

	  ws_90_day.set_column('C:C', 11, cell_format_date) # "cat_date"

	  ws_90_day.set_column('D:D', 10) # "media_type"

	  ws_90_day.set_column('E:E', 25) # "call_number"

	  ws_90_day.set_column('F:F', 12) # "vol"

	  ws_90_day.set_column('G:G', 30) # "author"

	  ws_90_day.set_column('H:H', 30) # "title"

	  ws_90_day.set_column('I:I', 14, cell_format_number) # "over_90_not_os"

	  ws_90_day.set_column('J:J', 14, cell_format_number) # "over_90_os"

	  ws_90_day.set_column('K:K', 14, cell_format_number) # "count_active_holds"

	  ws_90_day.set_column('L:L', 14, cell_format_number) # "count_active_copies"

	  ws_90_day.set_column('M:M', 14, cell_format_number) # "count_copies_on_order"

	  ws_90_day.freeze_panes(1, 0)

	  ws_90_day.write_row(0, 0,
	    (
	      "bib number",
	      "year\npublished",
	      "date\ncataloged",
	      "media\ntype(s)",
	      "call number",
		  "volume",
		  "author",
		  "title",
	      "over_90_not_os",
	      "over_90_os",
	      "active_holds",
	      "active_copies",
	      "copies_on_order"
	  ))

	  row_counter=1
	  for row in self.gen_sierra_data(self.ninety_day_output_sql):
	    #~ debug
	    #~ print(row_counter, end=": ")
	    #~ print(row)

	    # debug
	    # pdb.set_trace()

	    ws_90_day.write_row(row_counter, 0,
	      (
	        row['bib_num'],
	        row['pub_year'],
	        row['cat_date'],
	        row['media_type'],
	        row['call_number'],
			row['vol'],
			row['author'],
			row['title'],
	        row['over_90_not_os'],
	        row['over_90_os'],
	        row['count_active_holds'],
			row['count_active_copies'],
	        row['count_copies_on_order']
	    ))
	    row_counter+=1

	  wb.close()


if __name__ == "__main__":
	start_time = datetime.now()
	print('starting import at: \t\t{}'.format(start_time))

	app = App()

	import smtplib
	from email.mime.text import MIMEText
	from email.mime.application import MIMEApplication
	from email.mime.multipart import MIMEMultipart
	from os.path import basename
	config = configparser.ConfigParser()
	config.read('config.ini')

	msg = MIMEMultipart()
	# msg = MIMEText('System-Wide Holds Report: see attached')
	msg['Subject'] = 'System Wide Holds Report'
	msg['From'] = config['email']['email_from']
	msg['To'] = config['email']['email_to']
	msg.attach(MIMEText('System-Wide Holds Report: see attached'))

	# pdb.set_trace()
	file_name = app.system_wide_file_wb

	with open(file_name, 'rb') as open_file:
		part = MIMEApplication(
			open_file.read(),
			Name=basename(file_name)
		)
	part['Content-Disposition'] = 'attachment; filename="{}"'.format(basename(file_name))
	msg.attach(part)

	mailserver = smtplib.SMTP(config['email']['smtp_host'], 587)
	# identify ourselves to smtp client
	mailserver.ehlo()
	# secure our email with tls encryption
	mailserver.starttls()
	# re-identify ourselves as an encrypted connection
	mailserver.ehlo()
	mailserver.login(config['email']['smtp_username'], config['email']['smtp_password'])
	mailserver.sendmail(config['email']['email_from'],
		# sendmail expects recipients as a list
		[email.strip(' ') for email in config['email']['email_to'].split(',')],
		msg.as_string()
	)

	mailserver.quit()
	mailserver = None

	end_time = datetime.now()
	print('finished import at: \t\t{}'.format(end_time))
	print('total import time: \t\t{}'.format(end_time - start_time))
