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


class App:
	
	#~ the constructor
	def __init__(self):
		#~ the local database connection
		self.sqlite_conn = None
		#~ the remote database connection
		self.pgsql_conn = None
		
		#~ here are the queries we're using for this process
		#~ these files can be found in the same base project folder
		#~ 1) System-wide holds
		self.temp_tables_sql = 'base_holds_query_temp_tables.sql'
		self.bib_output_sql = 'base_holds_query-bib_output.sql'
		self.vol_output_sql = 'base_holds_query-vol_output.sql'
				
		self.bib_output_all_sql = 'base_holds_query_bib_output_all.sql'
		self.vol_output_all_sql = 'base_holds_query_vol_output_all.sql'
		
		#~ define our output directory (from the base of this directory)
		self.output_dir = os.getcwd() + "/output"
		if not os.path.exists(self.output_dir):
			os.makedirs(self.output_dir)
				
		#~ define our output for the excel spreadsheet
		#~ self.file_wb = os.getcwd() + date.today().strftime("/output/%Y-%m-%d-system_wide_holds.xlsx")
		self.file_wb = self.output_dir + date.today().strftime("/%Y-%m-%d-system_wide_holds.xlsx")
		self.wb = xlsxwriter.Workbook(self.file_wb)
		self.ws_bib_level = self.wb.add_worksheet("bib_level")
		self.ws_vol_level = self.wb.add_worksheet("vol_level")
		self.ws_bib_level_all = self.wb.add_worksheet("bib_level_all")
		self.ws_vol_level_all = self.wb.add_worksheet("vol_level_all")
		self.set_wb_params()
		
		self.test_sql = 'test.sql'
		
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
		
		
		"""
		bib_level
		"""
		#~ generate output for the bib_records matching our criteria
		
		#~ set the column names for the spreadsheet
		self.ws_bib_level.write_row(0, 0, 
			("bib_num", "active_holds", "active_copies", 
			"copies_on_order", "holds_to_copies", "bcode2"
		))
		
		row_counter=1
		for row in self.gen_sierra_data(self.bib_output_sql):
			#~ print("keys: ")
			#~ for key in row.keys():
				#~ print(key, end=", ")
			print(row_counter, end=": ")
			print(row)			
			
			self.ws_bib_level.write_row(row_counter, 0,
				(row['bib_num'], row['count_active_holds'],
				row['count_copies_on_order'], row['total_count_copies'],
				float(str("{0:.2f}").format(row['ratio_holds_to_copies'])),
				row['bcode2']
			))
			row_counter+=1
			
		"""
		/bib_level
		"""
		
		
		"""
		bib_level_all
		"""
		#~ generate output for the bib_records matching our criteria
		
		#~ set the column names for the spreadsheet
		self.ws_bib_level_all.write_row(0, 0, 
			("bib_num", "active_holds", "active_copies", 
			"copies_on_order", "holds_to_copies", "bcode2"
		))
		
		row_counter=1
		for row in self.gen_sierra_data(self.bib_output_all_sql):
			#~ print("keys: ")
			#~ for key in row.keys():
				#~ print(key, end=", ")
			print(row_counter, end=": ")
			print(row)			
			
			self.ws_bib_level_all.write_row(row_counter, 0,
				(row['bib_num'], row['count_active_holds'],
				row['count_copies_on_order'], row['total_count_copies'],
				float(str("{0:.2f}").format(row['ratio_holds_to_copies'])),
				row['bcode2']
			))
			row_counter+=1
			
		"""
		/bib_level_all
		"""
		
		
		
		"""
		vol_level
		"""
		#~ generate output for the vol_records matching our criteria
					
		#~ set the column names for the spreadsheet
		self.ws_vol_level.write_row(0, 0, 
			("bib_num", "vol_num", "vol", "active_holds", "active_copies", 
			"copies_on_order", "holds_to_copies", "bcode2"
		))
		
		row_counter=1
		for row in self.gen_sierra_data(self.vol_output_sql):
			#~ print("keys: ")
			#~ for key in row.keys():
				#~ print(key, end=", ")
			print(row_counter, end=": ")
			print(row)			
			
			self.ws_vol_level.write_row(row_counter, 0,
				(row['bib_num'], row['vol_num'], row['vol'], row['count_active_holds'],
				row['count_copies_on_order'], row['total_count_copies'],
				float(str("{0:.2f}").format(row['ratio_holds_to_copies'])),
				row['bcode2']
			))
			row_counter+=1
			
		"""
		/vol_level
		"""
		
		"""
		vol_level_all
		"""
		#~ generate output for the vol_records matching our criteria
		#~ set the column names for the spreadsheet
		self.ws_vol_level_all.write_row(0, 0, 
			("bib_num", "vol_num", "vol", "active_holds", "active_copies", 
			"copies_on_order", "holds_to_copies", "bcode2"
		))
		
		row_counter=1
		for row in self.gen_sierra_data(self.vol_output_all_sql):
			
			#~ debug
			#~ print(row_counter, end=": ")
			#~ print(row)			
			
			self.ws_vol_level_all.write_row(row_counter, 0,
				(row['bib_num'], row['vol_num'], row['vol'], row['count_active_holds'],
				row['count_copies_on_order'], row['total_count_copies'],
				float(str("{0:.2f}").format(row['ratio_holds_to_copies'])),
				row['bcode2']
			))
			row_counter+=1
			
		"""
		/vol_level_all
		"""
		
			
			
		#~ for some reason, this doesn't play nice in the destructor, so we do it here	
		self.wb.close()
	
	
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
		try:
			with self.pgsql_conn as conn:
				with conn.cursor() as cursor:
					cursor.execute(open(self.temp_tables_sql, "r").read())
		
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
			
			
	def set_wb_params(self):
		self.ws_bib_level.set_column('A:A', 10)
		self.ws_bib_level_all.set_column('A:A', 10)
		
		self.ws_bib_level.set_column('B:B', 10)
		self.ws_bib_level_all.set_column('B:B', 10)
		
		self.ws_bib_level.set_column('C:C', 12)
		self.ws_bib_level_all.set_column('C:C', 12)
		
		self.ws_bib_level.set_column('D:D', 14)
		self.ws_bib_level_all.set_column('D:D', 14)
		
		self.ws_bib_level.set_column('E:E', 14)
		self.ws_bib_level_all.set_column('E:E', 14)
		
		
		
		self.ws_vol_level.set_column('A:A', 10)
		self.ws_vol_level_all.set_column('A:A', 10)
		
		self.ws_vol_level.set_column('B:B', 10)
		self.ws_vol_level_all.set_column('B:B', 10)
		
		self.ws_vol_level.set_column('C:C', 14)
		self.ws_vol_level_all.set_column('C:C', 14)
		
		self.ws_vol_level.set_column('D:D', 12)
		self.ws_vol_level_all.set_column('D:D', 12)
				
		self.ws_vol_level.set_column('E:E', 12)
		self.ws_vol_level_all.set_column('E:E', 12)
		
		self.ws_vol_level.set_column('F:F', 14)
		self.ws_vol_level_all.set_column('F:F', 14)
		
		self.ws_vol_level.set_column('G:G', 14)
		self.ws_vol_level_all.set_column('G:G', 14)
		
		self.ws_vol_level.set_column('H:H', 10)
		self.ws_vol_level_all.set_column('H:H', 10)
		
		self.ws_bib_level.freeze_panes(1, 0)
		self.ws_vol_level.freeze_panes(1, 0)
		self.ws_bib_level_all.freeze_panes(1, 0)
		self.ws_vol_level_all.freeze_panes(1, 0)
		


start_time = datetime.now()
print('starting import at: \t\t{}'.format(start_time))
app = App()
end_time = datetime.now()
print('finished import at: \t\t{}'.format(end_time))
print('total import time: \t\t{}'.format(end_time - start_time))
