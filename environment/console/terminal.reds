Red/System [
	Title:	"Red GUI console common data structures and functions"
	Author: "Qingtian Xie"
	File: 	%terminal.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

terminal: context [

	#define RS_KEY_UNSET		 -1
	#define RS_KEY_NONE			  0
	#define RS_KEY_UP			-20
	#define RS_KEY_DOWN			-21
	#define RS_KEY_RIGHT		-22
	#define RS_KEY_LEFT			-23
	#define RS_KEY_END			-24
	#define RS_KEY_HOME			-25
	#define RS_KEY_INSERT		-26
	#define RS_KEY_DELETE		-27
	#define RS_KEY_PAGE_UP		-28
	#define RS_KEY_PAGE_DOWN	-29
	#define RS_KEY_CTRL_LEFT	-30
	#define RS_KEY_CTRL_RIGHT	-31
	#define RS_KEY_SHIFT_LEFT	-32
	#define RS_KEY_SHIFT_RIGHT	-33
	#define RS_KEY_CTRL_DELETE	-34
	#define RS_KEY_CTRL_A		1
	#define RS_KEY_CTRL_B		2
	#define RS_KEY_CTRL_C		3
	#define RS_KEY_CTRL_D		4
	#define RS_KEY_CTRL_E		5
	#define RS_KEY_CTRL_F		6
	#define RS_KEY_CTRL_H		8
	#define RS_KEY_TAB			9
	#define RS_KEY_CTRL_K		11
	#define RS_KEY_CTRL_L		12
	#define RS_KEY_ENTER		13
	#define RS_KEY_CTRL_N		14
	#define RS_KEY_CTRL_P		16
	#define RS_KEY_CTRL_T		20
	#define RS_KEY_CTRL_U		21
	#define RS_KEY_CTRL_V		22
	#define RS_KEY_CTRL_W		23
	#define RS_KEY_CTRL_Z		26
	#define RS_KEY_ESCAPE		27
	#define RS_KEY_BACKSPACE	127

	#define SCROLL_TOP		80000000h
	#define SCROLL_BOTTOM	7FFFFFFFh
	#define SCROLL_TRACK	7FFFFFFEh

	RECT_STRUCT: alias struct! [
		left		[integer!]
		top			[integer!]
		right		[integer!]
		bottom		[integer!]
	]

	line-node!: alias struct! [
		offset	[integer!]
		length	[integer!]
		nlines	[integer!]
	]

	ring-buffer!: alias struct! [
		lines	[line-node!]				;-- line-node! array
		head	[integer!]					;-- 1-based index
		tail	[integer!]					;-- 1-based index
		last	[integer!]					;-- index of last line
		nlines	[integer!]					;-- number of lines
		max		[integer!]					;-- maximum size of the line-node array
		h-idx	[integer!]					;-- offset of the first line
		s-head	[integer!]					;-- index of the first selected line
		s-tail	[integer!]					;-- index of the last selected line
		s-h-idx [integer!]					;-- offset of the first selected line
		s-t-idx [integer!]					;-- offset of the last selected line
		data	[red-string!]
	]

	terminal!: alias struct! [
		in			[red-string!]			;-- current input string
		buffer		[red-string!]			;-- line buffer for multiline support
		out			[ring-buffer!]			;-- output buffer
		history		[red-block!]
		history-pos [integer!]
		history-pre [integer!]
		history-beg [integer!]
		history-end [integer!]
		history-cnt [integer!]
		history-max [integer!]				;-- maximum number of lines in history block
		pos			[integer!]				;-- position of the scroll bar
		top			[integer!]				;-- index of the first visible line in out ring-buffer!
		top-offset	[integer!]				;-- for multiline support
		scroll		[integer!]				;-- number of lines to scroll
		nlines		[integer!]				;-- number of lines
		cols		[integer!]
		rows		[integer!]
		win-w		[integer!]
		win-h		[integer!]
		char-w		[integer!]
		char-h		[integer!]
		caret-x		[integer!]
		caret-y		[integer!]
		bg-color	[integer!]
		font-color	[integer!]
		pad-left	[integer!]
		caret?		[logic!]
		select?		[logic!]
		select-all? [logic!]
		ask?		[logic!]
		input?		[logic!]
		s-mode?		[logic!]
		s-head		[integer!]
		s-h-idx		[integer!]
		cursor		[integer!]				;-- cursor of edit line
		edit-pos	[integer!]
		edit-y		[integer!]				;-- cursor Y position
		edit-head	[integer!]
		edit-tail	[integer!]
		prompt-len	[integer!]				;-- length of prompt
		prompt		[red-string!]
		hwnd		[int-ptr!]				;@@ OS-Dependent field
		scrollbar	[int-ptr!]				;@@
		font		[int-ptr!]				;@@
	]

	v-terminal: 0
	extra-table: [0]						;-- extra unicode check table for Windows
	stub-table: [0 0]

	#include %wcwidth.reds

	#either OS = 'Windows [
		char-width?: func [
			cp		[integer!]
			return: [integer!]
		][
			either in-table? cp extra-table size? extra-table [2][wcwidth? cp]
		]
	][
		char-width?: func [
			cp		[integer!]
			return: [integer!]
		][
			wcwidth? cp
		]
	]

	string-lines?: func [
		str		[red-string!]
		offset	[integer!]
		length	[integer!]
		cols	[integer!]
		return: [integer!]
		/local
			n	[integer!]
	][
		n: string-width? str offset length cols
		either zero? n [1][n + cols - 1 / cols]
	]

	count-chars: func [
		str		[red-string!]
		offset	[integer!]
		length	[integer!]
		width	[integer!]
		return: [integer!]
		/local
			unit [integer!]
			len  [integer!]
			cp	 [integer!]
			w	 [integer!]
			s	 [series!]
			p0	 [byte-ptr!]
			p	 [byte-ptr!]
			tail [byte-ptr!]
	][
		s: GET_BUFFER(str)
		unit: GET_UNIT(s)
		p: (as byte-ptr! s/offset) + (offset << (unit >> 1))
		tail: p + (length << (unit >> 1))
		p0: p

		len: 0
		until [
			cp: string/get-char p unit
			w: char-width? cp
			if all [w = 2 len + 1 % width = 0][break]
			len: len + w
			p: p + unit
			any [len % width = 0 p = tail]
		]
		(as-integer p - p0) >> (unit >> 1)
	]

	string-width?: func [
		str		[red-string!]
		offset	[integer!]
		len		[integer!]
		column	[integer!]
		return: [integer!]
		/local
			unit [integer!]
			w	 [integer!]
			s	 [series!]
			p	 [byte-ptr!]
			tail [byte-ptr!]
	][
		s: GET_BUFFER(str)
		unit: GET_UNIT(s)
		p: (as byte-ptr! s/offset) + (offset << (unit >> 1))
		tail: either len = -1 [as byte-ptr! s/tail][p + (len << (unit >> 1))]

		len: 0
		while [p < tail][
			w: char-width? string/get-char p unit
			unless zero? column [
				either w = 2 [
					if len + 1 % column = 0 [w: 3]
				][w: 1]
			]
			len: len + w
			p: p + unit
		]
		len
	]

	reposition: func [
		vt		[terminal!]
		/local
			out		[ring-buffer!]
			data	[red-string!]
			lines	[line-node!]
			node	[line-node!]
			head	[integer!]
			tail	[integer!]
			cols	[integer!]
			w		[integer!]
			y		[integer!]
	][
		out: vt/out
		lines: out/lines
		head: vt/top
		tail: out/tail
		node: lines + head - 1
		y: node/nlines - vt/top-offset
		while [
			head: head % out/max + 1
			all [head <> tail y <= vt/rows]
		][
			node: lines + head - 1
			y: y + node/nlines
		]
		if y <= vt/rows [exit]

		cols: vt/cols
		data: out/data

		y: 0
		head: out/head
		until [
			tail: tail - 1
			if zero? tail [tail: out/max]
			if tail = head [break]
			node: lines + tail - 1
			w: string-width? data node/offset node/length cols
			y: w - 1 / cols + 1 + y
			y >= vt/rows
		]
		if tail <> head [
			vt/top: tail
			vt/scroll: y - vt/rows
			preprocess vt
		]
	]

	set-prompt: func [
		vt		[terminal!]
		prompt  [red-string!]
		/local
			input [red-string!]
	][
		input: vt/in
		string/rs-reset input
		vt/prompt: prompt
		string/concatenate input prompt -1 0 yes no
		vt/prompt-len: string/rs-length? prompt
		input/head: vt/prompt-len
		vt/cursor: vt/prompt-len
		emit-string vt prompt no no
		vt/edit-pos: vt/out/last
	]

	emit-c-string: func [
		vt		[terminal!]
		p		[byte-ptr!]
		tail	[byte-ptr!]
		unit	[integer!]
		last?	[logic!]
		append? [logic!]
		/local
			out		[ring-buffer!]
			data	[red-string!]
			lines	[line-node!]
			node	[line-node!]
			nlines	[integer!]
			added	[integer!]
			head	[integer!]
			n		[integer!]
			delta	[integer!]
			cursor	[integer!]
			buf		[series!]
			offset	[integer!]
			cp		[integer!]
			max		[integer!]
	][
		out: vt/out
		nlines: out/nlines
		max: out/max
		data: out/data
		added: 0
		head:	out/head
		cursor: either append? [out/last][out/tail]
		lines: out/lines
		node: lines + cursor - 1
		buf: GET_BUFFER(data)
		offset: either append? [node/offset][string/rs-length? data]
		cp: 0

		until [
			if p <> tail [
				cp: string/get-char p unit
				p: p + unit

				either cp = 9 [
					string/concatenate-literal data "    "
				][
					buf: string/append-char buf cp
				]
			]
			if any [cp = 10 p = tail][
				node/offset: offset
				offset: string/rs-length? data
				node/length: offset - node/offset
				unless last? [nlines: nlines + 1]
				if cp = 10 [node/length: node/length - 1]
				n: string-lines? data node/offset node/length vt/cols
				delta: either any [append? last?][n - node/nlines][n]
				node/nlines: n
				added: added + delta
				out/last: cursor
				cursor: cursor + 1
				if cursor > max [buf/tail: buf/offset cursor: 1]
				if cursor = head [head: head % max + 1]
				node: lines + cursor - 1
				node/nlines: 0
			]
			p = tail
		]
		node/offset: string/rs-length? data
		if cp = 10 [out/last: cursor]

		out/nlines: nlines
		out/head: head
		out/tail: cursor
		vt/nlines: vt/nlines + added

		reposition vt

		either nlines >= max [out/nlines: max vt/pos: vt/nlines - vt/rows + 1][
			if vt/nlines > vt/rows [vt/pos: vt/nlines - vt/rows + 1]
		]
	]

	emit-string: func [
		vt		[terminal!]
		str		[red-string!]
		last?	[logic!]
		append? [logic!]
		/local
			s		[series!]
			unit	[integer!]
			p		[byte-ptr!]
			tail	[byte-ptr!]
	][
		s: GET_BUFFER(str)
		unit: GET_UNIT(s)
		p: (as byte-ptr! s/offset) + (str/head << (unit >> 1))
		tail: as byte-ptr! s/tail
		emit-c-string vt p tail unit last? append?
	]

	preprocess: func [
		vt		[terminal!]
		/local
			out		[ring-buffer!]
			data	[red-string!]
			lines	[line-node!]
			node	[line-node!]
			cols	[integer!]
			offset	[integer!]
			start	[integer!]
			w		[integer!]
			y		[integer!]
	][
		start: vt/top
		cols: vt/cols
		offset: vt/scroll
		out: vt/out
		data: out/data
		lines: out/lines
		node: lines + start - 1
		case [
			all [
				negative? offset
				start <> out/head
			][
				until [
					start: start - 1
					if zero? start [start: out/max]
					node: lines + start - 1
					if start = out/head [offset: 0 break]
					w: string-width? data node/offset node/length cols
					y: w + cols - 1 / cols
					offset: y + offset
					offset >= 0
				]
			]
			all [
				positive? offset
				start <> out/tail
			][
				until [
					if start = out/last [offset: 0 break]
					w: string-width? data node/offset node/length cols
					y: w + cols - 1 / cols
					offset: offset - y
					if offset >= 0 [
						start: start % out/max + 1
						node: lines + start - 1
					]
					offset <= 0
				]
				if offset < 0 [offset: y + offset]
			]
			true [offset: 0]
		]

		out/h-idx: either positive? offset [
			count-chars data node/offset node/length cols * offset
		][0]
		vt/top: start
		vt/top-offset: offset
		vt/scroll: 0
	]

	insert-into-line: func [
		line	[red-string!]
		head	[integer!]
		cp		[integer!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(line)
		either head = string/rs-abs-length? line [
			string/append-char s cp
		][
			string/insert-char s head cp
		]
	]

	emit-char: func [
		vt		[terminal!]
		cp		[integer!]
		del?	[logic!]
		return: [logic!]
		/local
			input	[red-string!]
			node	[line-node!]
			out		[ring-buffer!]
			pos		[integer!]
			head	[integer!]
			len		[integer!]
			w		[integer!]
			s		[series!]
			tail	[byte-ptr!]
			select? [logic!]
	][
		input: vt/in
		out: vt/out
		len: either vt/edit-pos = out/last [string/rs-abs-length? input][0]

		select?: delete-selection vt
		head: vt/cursor

		either del? [
			if all [
				not select?
				any [
					head = vt/prompt-len
					head > len
				]
			][
				return false
			]
			unless select? [
				head: head - 1
				string/remove-char input head
			]
		][
			insert-into-line input head cp
			head: head + 1
		]
		vt/cursor: head

		cut-red-string out/data len
		if any [not del? len > 1][
			s: GET_BUFFER(input)
			out/tail: out/last
			tail: as byte-ptr! s/tail
			w: GET_UNIT(s)
			if cp = as-integer #"^[" [string/poke-char s tail - w 10]
			emit-c-string vt as byte-ptr! s/offset tail w yes no
			if cp = as-integer #"^[" [string/poke-char s tail - w 27]
			if cp = 10 [s/tail: as cell! tail - w]
		]
		true
	]

	scroll: func [
		vt		 [terminal!]
		distance [integer!]
		/local
			bottom	[integer!]
	][
		bottom: vt/nlines - vt/rows + 1
		switch distance [
			SCROLL_TOP		[vt/top: vt/out/head vt/pos: 1]
			SCROLL_BOTTOM	[vt/top: vt/out/last vt/pos: bottom]
			default [
				vt/scroll: vt/top-offset + distance
				vt/pos: vt/pos + distance
				if vt/pos > bottom [vt/pos: bottom]
				if vt/pos <= 0 [vt/pos: 1]
			]
		]
		preprocess vt
		refresh vt
	]

	hide-caret: func [vt [terminal!]][
		if vt/caret? [
			vt/caret?: no
			OS-hide-caret vt
		]
	]

	update-caret: func [
		vt [terminal!]
		/local
			cols	[integer!]
			x		[integer!]
	][
		cols: vt/cols
		x: string-width? vt/in 0 vt/cursor cols
		vt/caret-y: x - 1 / cols + vt/edit-y
		if positive? x [
			x: x % cols
			if zero? x [x: cols]
		]
		vt/caret-x: x
		OS-update-caret vt
	]

	refresh: func [
		vt		[terminal!]
		/local
			rc	[RECT_STRUCT]
	][
		rc: null
		;@@ calculate invalid rect
		OS-refresh vt rc
	]

	update-font: func [
		vt		[terminal!]
		char-x	[integer!]
		char-y	[integer!]
	][
		vt/cols: vt/win-w - vt/pad-left / char-x
		vt/rows: vt/win-h / char-y
		vt/char-w: char-x
		vt/char-h: char-y
	]

	init: func [
		vt		[terminal!]
		win-x	[integer!]
		win-y	[integer!]
		char-x	[integer!]
		char-y	[integer!]
		/local
			out		[ring-buffer!]
	][
		out: as ring-buffer! allocate size? ring-buffer!
		out/max: 4000
		out/tail: 1
		out/head: 1
		out/last: 1
		out/lines: as line-node! allocate out/max * size? line-node!
		out/lines/offset: 0
		out/lines/nlines: 0
		out/data: as red-string! string/rs-make-at ALLOC_TAIL(root) 4000
		out/nlines: 1
		out/h-idx: 0
		out/s-head: -1

		vt/bg-color: 00FCFCFCh
		vt/font-color: 00000000h
		vt/pad-left: 3
		vt/win-w: win-x
		vt/win-h: win-y
		update-font vt char-x char-y
		vt/out: out
		vt/in: as red-string! #get system/console/line
		vt/buffer: as red-string! #get system/console/buffer
		vt/history: as red-block! #get system/console/history
		vt/history-max: 200
		vt/history-pos: 0
		vt/history-beg: 1
		vt/history-end: 1
		vt/history-cnt: 1
		vt/pos: 1
		vt/top: 1
		vt/top-offset: 0
		vt/nlines: 0
		vt/scroll: 0
		vt/caret?: no
		vt/select?: no
		vt/select-all?: no
		vt/ask?: no
		vt/input?: no
		vt/s-mode?: no
		vt/edit-head: -1
		vt/prompt: as red-string! #get system/console/prompt
		vt/prompt-len: string/rs-length? vt/prompt

		OS-init vt
	]

	close: func [
		vt	[terminal!]
		/local
			ring [ring-buffer!]
	][
		unless null? vt [
			OS-close vt
			ring: vt/out
			free as byte-ptr! ring/lines
			free as byte-ptr! ring
			free as byte-ptr! vt
		]
	]

	cancel-select: func [
		vt [terminal!]
		/local
			out		[ring-buffer!]
			head	[integer!]
			tail	[integer!]
			max		[integer!]
			lines	[line-node!]
			node	[line-node!]
	][
		vt/select-all?: no
		out: vt/out
		lines: out/lines
		max: out/max
		head: out/s-head
		tail: out/s-tail % max + 1

		if head <> -1 [
			until [
				node: lines + head - 1
				node/nlines: node/nlines << 1 >>> 1
				head: head % max + 1
				head = tail
			]
		]
		out/s-head: -1
		out/s-tail: -1
		if vt/s-mode? [
			vt/s-mode?: no
			refresh vt
		]
	]

	mark-select: func [
		vt [terminal!]
		/local
			out		[ring-buffer!]
			head	[integer!]
			tail	[integer!]
			max		[integer!]
			lines	[line-node!]
			node	[line-node!]
	][
		out: vt/out
		lines: out/lines
		max: out/max
		head: out/s-head
		tail: out/s-tail % max + 1

		if head <> -1 [
			until [
				node: lines + head - 1
				node/nlines: node/nlines or 80000000h
				head: head % max + 1
				head = tail
			]
		]
	]

	check-direction: func [
		old		[integer!]
		new		[integer!]
		head	[integer!]
		tail	[integer!]
		return: [integer!]
	][
		either head < tail [
			new - old
		][
			either old >= head [
				either new >= head [new - old][1]
			][
				either new >= head [-1][new - old]
			]
		]
	]

	select: func [
		vt		[terminal!]
		x		[integer!]
		y		[integer!]
		start?	[logic!]
		return: [logic!]
		/local
			out		[ring-buffer!]
			cols	[integer!]
			head	[integer!]
			tail	[integer!]
			max		[integer!]
			len		[integer!]
			offset	[integer!]
			w		[integer!]
			lines	[line-node!]
			node	[line-node!]
			data	[red-string!]
			up?		[logic!]
	][
		if negative? x [x: 0]
		either negative? y [y: 0][
			if y > vt/win-h [y: vt/win-h]
		]
		up?: no
		cols: vt/cols
		out: vt/out
		data: out/data
		lines: out/lines
		max: out/max
		tail: out/tail
		y: y / vt/char-h

		head: vt/top
		node: lines + head - 1
		offset: node/offset + out/h-idx
		len: node/length - out/h-idx
		while [y > 0][
			w: string-lines? data offset len cols
			y: y - w
			if y < 0 [break]
			head: head % max + 1
			if head = tail [break]
			node: lines + head - 1
			offset: node/offset
			len: node/length
		]
		if all [start? head = tail][return false]
		if head = tail [
			head: out/last
			y: w
		]

		unless zero? y [y: w + y]
		x: vt/char-w / 2 + x - vt/pad-left / vt/char-w
		if any [zero? len y > 0 x <> 0][
			x: either zero? len [0][
				count-chars data offset len cols * y + x
			]
			if head = vt/top [x: out/h-idx + x]
		]
		either start? [
			vt/s-head: head
			vt/s-h-idx: x
			out/s-head: head
			out/s-h-idx: x
			out/s-tail: head
			out/s-t-idx: x
		][
			w: check-direction vt/s-head head out/head out/tail
			either negative? w [up?: yes][
				if positive? w [up?: no]
			]
			out/s-head: either up? [head][vt/s-head]
			out/s-tail: either up? [vt/s-head][head]
			out/s-h-idx: either up? [x][vt/s-h-idx]
			out/s-t-idx: either up? [vt/s-h-idx][x]
			if all [zero? w x < vt/s-h-idx <> up?][
				y: out/s-h-idx
				out/s-h-idx: out/s-t-idx
				out/s-t-idx: y
			]
		]
		vt/select?: yes
		true
	]

	select-all: func [
		vt		[terminal!]
		/local
			out  [ring-buffer!]
			node [line-node!]
	][
		out: vt/out
		node: out/lines + out/last - 1
		cancel-select vt
		vt/select-all?: yes
		out/s-head: out/head
		out/s-h-idx: 0
		out/s-tail: out/last
		out/s-t-idx: node/length
	]

	fetch-history: func [
		vt		[terminal!]
		up?		[logic!]
		/local
			hist	[red-block!]
			input	[red-string!]
			len		[integer!]
			idx		[integer!]
			beg		[integer!]
			end		[integer!]
			s		[series!]
	][
		hist: vt/history
		idx: vt/history-pos
		if zero? idx [exit]

		beg: vt/history-beg
		end: vt/history-end
		input: vt/in
		len: string/rs-length? input
		cut-red-string input len

		unless up? [
			idx: either 1 = block/rs-length? hist [end][vt/history-pre]
		]
		either idx <> end [
			string/concatenate input as red-string! block/rs-abs-at hist idx - 1 -1 0 yes no
			vt/history-pos: either idx = beg [beg][idx - 1]
			vt/history-pre: idx % vt/history-cnt + 1
		][
			vt/history-pos: either end - 1 = 0 [vt/history-max][end - 1]
			vt/history-pre: end
		]

		cut-red-string vt/out/data len
		emit-string vt input yes yes
		input/head: vt/prompt-len
		vt/cursor: string/rs-abs-length? input
	]

	add-history: func [
		vt		[terminal!]
		/local
			str		[red-value!]
			history [red-block!]
			max		[integer!]
			end		[integer!]
			len		[integer!]
			add?	[logic!]
	][
		str: as red-value! vt/in
		history: vt/history
		max: vt/history-max
		end: vt/history-end
		len: block/rs-length? history
		add?: no
		unless any [
			zero? string/rs-length? as red-string! str
			all [
				len > 0
				zero? string/equal? as red-string! str as red-string! block/rs-abs-at history len - 1 COMP_STRICT_EQUAL no
			]
		][
			add?: yes
			str: as red-value! _series/copy
				 as red-series! str
				 as red-series! stack/push*
				 stack/arguments true stack/arguments

			either vt/history-cnt = max [
				_series/poke as red-series! history end str null
				vt/history-beg: vt/history-beg % max + 1
			][
				block/rs-append history str
				vt/history-cnt: vt/history-cnt + 1
			]
			stack/pop 1
		]
		either add? [
			vt/history-pos: end
			vt/history-end: end % max + 1
		][
			if len > 0 [vt/history-pos: either end - 1 = 0 [max][end - 1]]
		]
		vt/history-pre: vt/history-end
	]

	cut-red-string: func [
		str [red-string!]
		len [integer!]
		/local
			s [series!]
	][
		if len = -1 [len: string/rs-length? str]
		s: GET_BUFFER(str)
		s/tail: as cell! (as byte-ptr! s/tail) - (len << (GET_UNIT(s) >> 1))
	]

	complete-line: func [
		vt			[terminal!]
		str			[red-string!]
		return:		[integer!]
		/local
			out		[ring-buffer!]
			line	[red-string!]
			result	[red-block!]
			num		[integer!]
			str2	[red-string!]
			head	[integer!]
	][
		line: declare red-string!
		_series/copy
			as red-series! str
			as red-series! line
			stack/arguments
			yes
			stack/arguments

		line/head: vt/cursor - vt/prompt-len
		#call [default-input-completer line]
		result: as red-block! stack/arguments
		num: block/rs-length? result

		out: vt/out
		unless zero? num [
			cut-red-string out/data string/rs-length? str
			cut-red-string str -1

			either num = 1 [
				str2: as red-string! block/rs-head result
				vt/cursor: vt/prompt-len + str2/head
				str2/head: 0
				string/concatenate str str2 -1 0 yes no
			][
				until [
					string/concatenate str as red-string! block/rs-head result -1 0 yes no
					string/append-char GET_BUFFER(str) 32
					block/rs-next result
					block/rs-tail? result
				]
				string/append-char GET_BUFFER(str) 10
			]
			out/tail: out/last
			emit-string vt str yes yes
			if num > 1 [
				cut-red-string str -1
				line/head: 0
				string/concatenate str line -1 0 yes no
				head: str/head
				str/head: 0
				emit-string vt str no no
				str/head: head
			]
		]
		num
	]

	move-cursor: func [
		vt		[terminal!]
		left?	[logic!]
		/local
			input	[red-string!]
			cursor	[integer!]
	][
		input: vt/in
		cursor: vt/cursor
		vt/cursor: either left? [
			if input/head = cursor [exit]
			cursor - 1
		][
			if cursor = string/rs-abs-length? input [exit]
			cursor + 1
		]
		update-caret vt
	]

	check-cursor: func [
		vt		[terminal!]
		/local
			out [ring-buffer!]
	][
		out: vt/out
		if all [
			any [
				vt/s-head = out/last
				out/s-tail = out/last
			]
			out/s-t-idx >= vt/prompt-len
		][
			vt/cursor: either all [
				out/s-tail = out/s-head
				vt/s-h-idx > out/s-h-idx
			][
				out/s-h-idx
			][
				out/s-t-idx
			]
			if vt/cursor < vt/prompt-len [vt/cursor: vt/prompt-len]
			update-caret vt
		]
	]

	check-selection: func [
		vt		[terminal!]
		/local
			out		[ring-buffer!]
			input	[red-string!]
	][
		out: vt/out
		input: vt/in
		if all [
			out/s-head <> -1
			out/s-tail = out/last
		][
			vt/edit-head: either out/s-head = out/s-tail [out/s-h-idx][0]
			if vt/edit-head < vt/prompt-len [vt/edit-head: vt/prompt-len]
			vt/edit-tail: out/s-t-idx
			vt/s-mode?: yes
		]
	]

	select-edit: func [
		vt		[terminal!]
		left?	[logic!]
		/local
			x	[integer!]
			y	[integer!]
	][
		x: vt/caret-x * vt/char-w
		y: vt/caret-y * vt/char-h
		unless vt/s-mode? [
			cancel-select vt
			select vt x y yes
			mark-select vt
			vt/s-mode?: yes
		]
		move-cursor vt left?
		x: vt/caret-x * vt/char-w
		select vt x y no
		vt/edit-head: vt/out/s-h-idx
		vt/edit-tail: vt/out/s-t-idx
		if vt/edit-head = vt/edit-tail [vt/edit-head: -1]
		vt/select?: no
	]

	delete-selection: func [
		vt		[terminal!]
		return: [logic!]
		/local
			input	[red-string!]
			head	[integer!]
	][
		head: vt/edit-head
		if head <> -1 [
			input: vt/in
			string/remove-part input head vt/edit-tail - head
			vt/cursor: head
			vt/edit-head: -1
			return true
		]
		false
	]

	edit: func [
		vt		[terminal!]
		cp		[integer!]
		/local
			out		[ring-buffer!]
			input	[red-string!]
			cursor	[integer!]
			cue		[red-string!]
	][
		unless vt/input? [exit]

		out: vt/out
		input: vt/in
		cursor: vt/cursor

		if all [
			cp <> RS_KEY_SHIFT_LEFT
			cp <> RS_KEY_SHIFT_RIGHT
			cp <> RS_KEY_CTRL_C
			any [out/s-head <> -1 vt/s-mode?]
		][
			cancel-select vt
		]

		switch cp [
			RS_KEY_NONE [exit]
			RS_KEY_TAB [
				if zero? complete-line vt input [edit vt 32]
			]
			RS_KEY_ENTER [
				vt/input?: no
				hide-caret vt
				cursor: string/rs-abs-length? input
				vt/cursor: cursor
				unless 27 = string/rs-abs-at input cursor - 1 [
					add-history vt
					emit-char vt 10 no
				]
				if vt/ask? [
					vt/ask?: no
					gui/PostQuitMessage 0
				]
			]
			RS_KEY_CTRL_H
			RS_KEY_BACKSPACE [unless emit-char vt cp yes [exit]]
			RS_KEY_CTRL_B
			RS_KEY_LEFT [
				move-cursor vt yes
				vt/edit-head: -1
				exit
			]
			RS_KEY_CTRL_F
			RS_KEY_RIGHT [
				move-cursor vt no
				vt/edit-head: -1
				exit
			]
			RS_KEY_UP
			RS_KEY_CTRL_P [fetch-history vt yes]
			RS_KEY_DOWN
			RS_KEY_CTRL_N [fetch-history vt no]
			RS_KEY_CTRL_A [select-all vt]
			RS_KEY_HOME [
				vt/cursor: input/head
				update-caret vt
			]
			RS_KEY_CTRL_E
			RS_KEY_END [
				vt/cursor: string/rs-abs-length? input
				update-caret vt
			]
			RS_KEY_DELETE [
				vt/cursor: vt/cursor + 1
				unless emit-char vt cp yes [
					vt/cursor: vt/cursor - 1
					exit
				]
			]
			RS_KEY_CTRL_C [
				copy-to-clipboard vt
				exit
			]
			RS_KEY_CTRL_V [
				paste-from-clipboard vt no
				vt/edit-head: -1
				exit
			]
			RS_KEY_ESCAPE [
				vt/cursor: string/rs-abs-length? input
				emit-char vt cp no
				edit vt RS_KEY_ENTER
			]
			RS_KEY_CTRL_LEFT   [0]
			RS_KEY_SHIFT_LEFT  [
				select-edit vt yes
			]
			RS_KEY_CTRL_RIGHT  [0]
			RS_KEY_SHIFT_RIGHT [
				select-edit vt no
			]
			RS_KEY_CTRL_DELETE [0]
			default [
				if cp < 32 [exit]
				emit-char vt cp no
			]
		]
		unless vt/s-mode? [vt/edit-head: -1]
		refresh vt
	]

	set-text-color: func [
		vt			[terminal!]
		select?		[logic!]
		inversed?	[logic!]
		return:		[logic!]
	][
		either select? [
			unless inversed? [
				inversed?: yes
				set-select-color vt
			]
		][
			if inversed? [
				inversed?: no
				set-normal-color vt
			]
		]
		inversed?
	]

	paint-select: func [
		vt		[terminal!]
		line	[red-string!]
		length	[integer!]
		start	[integer!]
		end		[integer!]
		y		[integer!]
		return: [integer!]
		/local
			offset	[integer!]
			cols	[integer!]
			x		[integer!]
			w		[integer!]
			s		[series!]
			unit	[integer!]
			cp		[integer!]
			char-h	[integer!]
			win-w	[integer!]
			p		[byte-ptr!]
			str		[c-string!]
	][
		win-w: vt/win-w
		cols: win-w - vt/pad-left
		char-h: vt/char-h
		offset: line/head
		s: GET_BUFFER(line)
		unit: GET_UNIT(s)
		p: string/rs-head line
		x: 0
		while [length > 0][
			either all [
				offset >= start
				offset < end
			][
				set-select-color vt
			][
				set-normal-color vt
			]
			cp: string/get-char p unit
			str: as c-string! :cp
			w: vt/char-w * char-width? cp
			length: length - 1
			offset: offset + 1
			p: p + unit
			if x + w > cols [
				OS-draw-text null 0 x y win-w - x char-h
				x: 0
				y: y + char-h
			]
			OS-draw-text str 1 x y w char-h
			x: x + w
		]
		unless vt/select-all? [set-normal-color vt]
		if x < win-w [
			OS-draw-text null 0 x y win-w - x char-h
		]
		y + char-h
	]

	paint: func [
		vt		[terminal!]
		/local
			y			[integer!]
			char-h		[integer!]
			win-w		[integer!]
			win-h		[integer!]
			out			[ring-buffer!]
			cnt			[integer!]
			start		[integer!]
			end			[integer!]
			tail		[integer!]
			len			[integer!]
			offset		[integer!]
			nlines		[integer!]
			cols		[integer!]
			lines		[line-node!]
			node		[line-node!]
			data		[red-string!]
			select?		[logic!]
			inversed?	[logic!]
			c-str		[c-string!]
			n			[integer!]
	][
		win-w: vt/win-w
		win-h: vt/win-h
		char-h: vt/char-h
		cols: vt/cols
		out: vt/out
		data: out/data
		lines: out/lines
		select?: no
		inversed?: no
		start: vt/top
		tail: out/tail
		node: lines + start - 1
		offset: node/offset + out/h-idx
		len: node/length - (offset - node/offset)
		y: 0

		if vt/select-all? [set-select-color vt]

		while [all [start <> tail y < win-h]][
			nlines: node/nlines
			select?: nlines and 80000000h <> 0
			either not zero? len [
				n: string-lines? data node/offset node/length cols
				data/head: offset
				case [
					start = out/s-head [
						end: either out/s-head = out/s-tail [
							out/s-t-idx
						][
							node/length
						]
						y: paint-select vt data len node/offset + out/s-h-idx node/offset + end y
					]
					all [
						out/s-head <> out/s-tail
						start = out/s-tail
					][
						y: paint-select vt data len offset node/offset + out/s-t-idx y
					]
					true [
						inversed?: set-text-color vt select? inversed?
						while [len > 0][
							cnt: count-chars data offset len cols
							data/head: offset
							len: len - cnt
							offset: offset + cnt
							c-str: unicode/to-utf16-len data :cnt
							OS-draw-text c-str cnt 0 y win-w char-h
							y: y + char-h
						]
						nlines: nlines and 7FFFFFFFh
						if n - nlines <> 0 [
							vt/nlines: vt/nlines + n - nlines
							node/nlines: node/nlines and 80000000h or n
						]
					]
				]
			][
				inversed?: set-text-color vt select? inversed?
				OS-draw-text null 0 0 y win-w char-h
				y: y + char-h
			]
			start: start % out/max + 1
			node: lines + start - 1	
			offset: node/offset
			len: node/length
		]
		vt/edit-y: either all [
			start = tail
			y <= win-h
		][y / char-h - n][vt/rows + 2]
		if any [vt/select-all? inversed?][set-normal-color vt]
		data/head: 0
		until [
			OS-draw-text null 0 0 y win-w char-h
			y: y + char-h
			y > win-h
		]
	]

	with gui [
		#switch OS [
			Windows  [#include %windows.reds]
			Android  []
			MacOSX   []
			FreeBSD  []
			Syllable []
			#default []										;-- Linux
		]
	]

	ask: func [
		question	[red-string!]
		return:		[red-string!]
		/local
			vt		[terminal!]
	][
		vt: as terminal! v-terminal
		vt/input?: yes
		set-prompt vt question
		refresh vt
		unless paste-from-clipboard vt yes [
			vt/ask?: yes
			update-caret vt
			stack/mark-func words/_body
			gui/do-events no
			stack/unwind
		]
		vt/in
	]

	vprint: func [
		str		[byte-ptr!]
		size	[integer!]
		unit	[integer!]
		nl?		[logic!]
		/local
			vt	[terminal!]
			out [ring-buffer!]
	][
		if negative? size [
			size: length? as c-string! str
		]
		vt: as terminal! v-terminal
		out: vt/out
		out/nlines: out/nlines - 1
		emit-c-string vt str str + size unit no yes
		if nl? [
			str: as byte-ptr! "^/"
			emit-c-string vt str str + 1 1 no yes
		]
		refresh vt
	]
]