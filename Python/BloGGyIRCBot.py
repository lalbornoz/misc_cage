#!/usr/bin/env python
# $Id$
#

from collections	import deque
from ircbot		import SingleServerIRCBot
from subprocess		import PIPE, Popen
from threading		import Thread
import select

class BloGGyIRCBot (SingleServerIRCBot):
	def __init__ (self, server, port, nickname, channel):
		SingleServerIRCBot.__init__ (self, [(server, port)], nickname, nickname)
		self.channel = channel

	def on_welcome (self, connection, event):
		print "Connected to " + connection.server + ":" + str (connection.port) + "."
		print "Joining channel " + self.channel
		connection.join (self.channel)

	def on_pubmsg (self, connection, event):
		sender = event.source().split ('!', 1)[0]
		print "<" + sender + "> " + event.arguments ()[0]

class BloGGyBotThread (Thread):
	def __init__ (self, bot_queue):
		Thread.__init__ (self)
		self.irc_queue = irc_queue
		self.bot = BloGGyIRCBot ("127.0.0.1", 6667, "BloGGy", "#arab")

	def run (self):
		self.bot.start ()

class BloGGyESpeakThread (Thread):
	def __init__ (self, espeak_queue):
		Thread.__init__ (self)
		self.espeak_queue = espeak_queue
		self.espeak = Popen (
				"espeak --stdout", bufsize=65535,
				stdin=PIPE, stdout=PIPE, stderr=PIPE,
				shell=True)

	def run (self):
		select.select ((self.espeak.stdout, self.espeak.stderr), (), ())

def main ():
	global bot_queue, bot_thread, espeak_thread

	queue_bot = deque ()
	espeak_thread = BloGGyESpeakThread (queue_bot)
	espeak_thread.start ()
	bot_thread = BloGGyBotThread (queue_bot)
	bot_thread.start ()
	bot_thread.join ()

if __name__ == '__main__':
	main()

# vim:ts=8 sw=8 tw=120 noexpandtab fileencoding=utf-8 foldmethod=marker
