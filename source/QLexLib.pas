{*****************************************************************************}
{   TxQuery DataSet                                                           }
{                                                                             }
{   The contents of this file are subject to the Mozilla Public License       }
{   Version 1.1 (the "License"); you may not use this file except in          }
{   compliance with the License. You may obtain a copy of the License at      }
{   http://www.mozilla.org/MPL/                                               }
{                                                                             }
{   Software distributed under the License is distributed on an "AS IS"       }
{   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the   }
{   License for the specific language governing rights and limitations        }
{   under the License.                                                        }
{                                                                             }
{   The Original Code is: QLEXLIB.pas                                         }
{                                                                             }
{                                                                             }
{   The Initial Developer of the Original Code is Alfonso Moreno.             }
{   Portions created by Alfonso Moreno are Copyright (C) <1999-2003> of       }
{   Alfonso Moreno. All Rights Reserved.                                      }
{   Open Source patch reviews (2009-2012) with permission from Alfonso Moreno }
{                                                                             }
{   Alfonso Moreno (Hermosillo, Sonora, Mexico)                               }
{   email: luisarvayo@yahoo.com                                               }
{     url: http://www.ezsoft.com                                              }
{          http://www.sigmap.com/txquery.htm                                  }
{                                                                             }
{   Contributor(s): Chee-Yang, CHAU (Malaysia) <cychau@gmail.com>             }
{                   Sherlyn CHEW (Malaysia)                                   }
{                   Francisco Due�as Rodriguez (Mexico) <fduenas@gmail.com>   }
{                                                                             }
{              url: http://code.google.com/p/txquery/                         }
{                   http://groups.google.com/group/txquery                    }
{                                                                             }
{*****************************************************************************}

Unit QLexLib;

{$I XQ_FLAG.INC}
Interface

Uses Classes, SysUtils, QFormatSettings, XQTypes;

Const
  nl = #10; (* newline character *)
  max_chars = maxint div {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}; { patched by ccy }
  max_matches = 1024;
  max_rules = 256;
  intial_bufsize = 16384;

Type

  PCharArray = ^TCharArray;
  TCharArray = array [1..max_chars] of TxNativeChar;

  {modified by fduenas: move YYSType here to make TP Yacc/Lex thread safe)}
  YYSType = record
               yystring : TxNativeString
            end
  (*YYSType*);

  TCustomLexer = Class
  private
    (*
     Some state information is maintained to keep track with calls to yymore,
     yyless, reject, start and yymatch/yymark, and to initialize state
     information used by the lexical analyzer.
     - Fyystext: contains the initial contents of the yytext variable; this
       will be the empty string, unless yymore is called which sets Fyystext
       to the current yytext
     - Fyysstate: start state of lexical analyzer (set to 0 during
       initialization, and modified in calls to the start routine)
     - Fyylstate: line state information (1 if at beginning of line, 0
       otherwise)
     - Fyystack: stack containing matched rules; Fyymatches contains the number of
       matches
     - Fyypos: for each rule the last marked position (yymark); zeroed when rule
       has already been considered
     - Fyysleng: copy of the original yyleng used to restore state information
       when reject is used
    *)
    Fyystext: TxNativeString;
    Fyysstate: Integer;
    Fyylstate: Integer;
    Fyymatches: Integer;
    Fyystack: array[1..max_matches] of Integer;
    Fyypos: array[1..max_rules] of Integer;
    Fyysleng: Byte;
    function GetBuf(Index: Integer): TxNativeChar;
    procedure SetBuf(Index: Integer; Value: TxNativeChar);
  Public
    //yyinput, yyoutput : Text;      (* input and output file            *)
    //yyerrorfile       : Text;      (* standard error file              *)
    yyRuntimeFormatSettings: TFormatSettings;
    yySystemFormatSettings: TFormatSettings;
    yyinput, yyoutput: TStream; (* input and output file            *)
    yyerrorfile: TStream; (* standard error file              *)
    yyline: TxNativeString; (* current input line               *)
    yylineno, yycolno: Integer; (* current input position           *)
    //yytext: String; (* matched text                     *)
    yyTextBuf         : PCharArray;
    yyTextLen         : Integer;
    yyTextBufSize     : Integer;
    yylValInternal: YYSType; {added by fduenas: for use when using only the Lexer without the parser}
    (*   (should be considered r/o)     *)
{yyleng            : Byte         (* length of matched text *)
absolute yytext;                incompatible with Delphi 2.0       }

(* I/O routines:

The following routines get_char, unget_char and put_char are used to
implement access to the input and output files. Since \n (newline) for
Lex means line end, the I/O routines have to translate MS-DOS line ends
(carriage-return/line-feed) into newline characters and vice versa. Input
is buffered to allow rescanning text (via unput_char).

The input buffer holds the text of the line to be scanned. When the input
buffer empties, a new line is obtained from the input stream. Characters
can be returned to the input buffer by calls to unget_char. At end-of-
file a null character is returned.

The input routines also keep track of the input position and set the
yyline, yylineno, yycolno variables accordingly.

Since the rest of the Lex library only depends on these three routines
(there are no direct references to the yyinput and yyoutput files or
to the input buffer), you can easily replace get_char, unget_char and
put_char by another suitable set of routines, e.g. if you want to read
from/write to memory, etc. *)

    Function get_char: TxNativeChar;
    (* obtain one character from the input file (null character at end-of-
       file) *)

    Procedure unget_char( c: TxNativeChar );
    (* return one character to the input file to be reread in subsequent
       calls to get_char *)

    Procedure put_char( c: TxNativeChar );
    (* write one character to the output file *)

  (* Utility routines: *)

    Procedure echo;
    (* echoes the current match to the output stream *)

    Procedure yymore;
    (* append the next match to the current one *)

    Procedure yyless( n: Integer );
    (* truncate yytext to size n and return the remaining characters to the
       input stream *)

    Procedure reject;
    (* reject the current match and execute the next one *)

    (* reject does not actually cause the input to be rescanned; instead,
       internal state information is used to find the next match. Hence
       you should not try to modify the input stream or the yytext variable
       when rejecting a match. *)

    Procedure returni( n: Integer );
    Procedure returnc( c: TxNativeChar );
    (* sets the return value of yylex *)

    Procedure start( state: Integer );
    (* puts the lexical analyzer in the given start state; state=0 denotes
       the default start state, other values are user-defined *)

  (* yywrap:

     The yywrap function is called by yylex at end-of-file (unless you have
     specified a rule matching end-of-file). You may redefine this routine
     in your Lex program to do application-dependent processing at end of
     file. In particular, yywrap may arrange for more input and return false
     in which case the yylex routine resumes lexical analysis. *)

    Function yywrap: Boolean;
    (* The default yywrap routine supplied here closes input and output
       files and returns true (causing yylex to terminate). *)

  (* The following are the internal data structures and routines used by the
     lexical analyzer routine yylex; they should not be used directly. *)

    Function yylex( var yylval: YYSType ): Integer; overload; Virtual;  Abstract; {modified by fduenas: yylval variable for thread safe)}
    function yylexinternal: Integer; overload; virtual;  {added by fduenas: for use when using only the Lexer without the parser}
    (* this function must be overriden by the Lexer descendent in order
       to provide the lexing service *)
    constructor Create;
    destructor Destroy; override;
    procedure CheckBuffer(Index : integer);
    procedure CheckyyTextBuf(Size : integer);
    procedure GetyyText(var s : TxNativeString);
    property Buf[Index: Integer]: TxNativeChar read GetBuf write SetBuf;

  Protected
    yystate: Integer; (* current state of lexical analyzer *)
    yyactchar: TxNativeChar; (* current character *)
    yylastchar: TxNativeChar; (* last matched character (#0 if none) *)
    yyrule: Integer; (* matched rule *)
    yyreject: Boolean; (* current match rejected? *)
    yydone: Boolean; (* yylex return value set? *)
    yyretval: Integer; (* yylex return value *)
    bufptr: Integer;
    //buf: Array[1..max_chars] Of TxNativeChar;
    bufSize : Integer;
    FBuf : PCharArray;

    Procedure yynew;
    (* starts next match; initializes state information of the lexical
       analyzer *)

    Procedure yyscan;
    (* gets next character from the input stream and updates yytext and
       yyactchar accordingly *)

    Procedure yymark( n: Integer );
    (* marks position for rule no. n *)

    Procedure yymatch( n: Integer );
    (* declares a match for rule number n *)

    Function yyfind( Var n: Integer ): Boolean;
    (* finds the last match and the corresponding marked position and
       adjusts the matched string accordingly; returns:
       - true if a rule has been matched, false otherwise
       - n: the number of the matched rule *)

    Function yydefault: Boolean;
    (* executes the default action (copy character); returns true unless
       at end-of-file *)

    Procedure yyclear;
    (* reinitializes state information after lexical analysis has been
       finished *)

    Procedure fatal( msg: TxNativeString );
    (* writes a fatal error message and halts program *)

  End; (* TCustomLexeer *)

Function eof( aStream: Tstream ): boolean;
Procedure readln( aStream: TStream; Var aLine: TxNativeString );
Procedure writeln( aStream: TStream; aline: TxNativeString );
Procedure write( aStream: TStream; aLine: TxNativeString );

Implementation

uses
  math, QCnvStrUtils;

(* utility procedures *)

Function eof( aStream: Tstream ): boolean;
Begin
  result := aStream.position >= aStream.size;
End;

Procedure readln( aStream: TStream; Var aLine: TxNativeString );
Var
  //aBuffer: String;
  CRBuf : TxNativeString;
  trouve: boolean;
  unCar: TxNativeChar;
  Buf : TxNativePChar;
  BufSize : Integer;
  i : Integer;

  procedure CheckBuffer;
  begin
     repeat
      //we need to take into account size of char - we are increasing
      //position in stream by SizeOf(char) and not by a byte
      if (i * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}) >=
         (BufSize - {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}) then
      //(- SizeOf(Char) is needed if BufSize is odd number and
      //GetMem works in chunks of 1 byte
      begin
        BufSize := Max (BufSize *
         {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}, BufSize + 256 );
        ReallocMem (Buf, BufSize);
      end;
    until (i * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}) <
          (BufSize - {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF});

  end;

Begin
  // ??????
  //aBuffer := '';
  BufSize := 256;
  i := 0;
  GetMem (Buf, BufSize * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
  FillChar(Buf^, BufSize * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}, #0); {added by fduenas}
  try
    trouve := false;
    Repeat
      aStream.read( unCar, 1 * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF} ); { patched by ccy }
      If aStream.Position >= aStream.Size Then
      Begin
        trouve := true;
        if not CharInSet(unCar, [#10,#13]) then
        begin
          //aLine := aBuffer+unCar
          Inc (i);
          CheckBuffer;
          Move (uncar, Buf [i - 1], 1 * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
          SetLength (aLine, i);
          Move (Buf^, aLine [1], i * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
        end else
        begin
          if i > 0 then
          begin
            SetLength (aLine, i);
            Move (Buf^, aLine [1], i * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
          end else
            aLine:='';
        end;
      End
      Else
        Case unCar Of
          #10, #11: {added by fduenas: char(11) some times is assigned when assigning TRichEdit.Lines.Text to SQL | SQL Script property}
            Begin
              //aLine := aBuffer;
              if i>0 then
              begin
                SetLength (aLine, i);
                Move (Buf^, aLine [1], i * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
                trouve := true;
              end else
                aLine:= '';
            End;
          #13:
            Begin
              aStream.read( unCar, 1 * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
              If {$if RtlVersion <= 18.5} unCar in [#10,#11] {$else} CharInSet(unCar, [#10, #11]) {$ifend} Then {patched by fduenas: some times a char(11) is added to end of each line
                                                    when assigning TRichEdit.Lines.Text to SQL | SQL Script property}
              Begin
                //aLine := aBuffer;
                if i > 0 then
                begin
                  SetLength (aLine, i);
                  Move (Buf^, aLine [1], i * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
                  trouve := true;
                end else
                  aLine:='';
              End
              Else
              Begin
                Inc (i, 2);
                CheckBuffer;
                CRBuf := #13 + unCar;
                Move (CRBuf [1], Buf [i - 2], 2 * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
                //aBuffer := aBuffer + #13 + unCar;
              End;
            End;
        Else
          //aBuffer := aBuffer + unCar;
        begin
          Inc (i);
          CheckBuffer;
          Move (unCar, Buf [i - 1], 1 * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
          //aBuffer := aBuffer+unCar;
        end;

        End;
    Until trouve;
  finally
    FreeMem (Buf, BufSize * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF});  { patched by ccy }
  end;
End;

Procedure writeln( aStream: TStream; aline: TxNativeString );
Const
  FINLIGNE: Array[1..2] Of TxNativeChar = ( #13, #10 );
Begin
  // ??????
  write( aStream, aLine );
  aStream.write( FINLIGNE, 2 );
End;

Procedure write( aStream: TStream; aLine: TxNativeString );
Const
  WRITEBUFSIZE = 8192;
Var
  aBuffer: Array[1..WRITEBUFSIZE] Of TxNativeChar;
  j, nbuf: integer;
  k, nreste: integer;
Begin
  nbuf := length( aLine ) Div WRITEBUFSIZE;
  nreste := length( aLine ) - ( nbuf * WRITEBUFSIZE );
  For j := 0 To nbuf - 1 Do
  Begin
    For k := 1 To WRITEBUFSIZE Do
      aBuffer[k] := aLine[j * WRITEBUFSIZE + k];
    aStream.write( aBuffer, WRITEBUFSIZE );
  End;
  For k := 1 To nreste Do
    aBuffer[k] := aLine[nbuf * WRITEBUFSIZE + k];
  aStream.write( aBuffer, nreste );
End;

Procedure TCustomLexer.fatal( msg: TxNativeString );
(* writes a fatal error message and halts program *)
Begin
  writeln( yyerrorfile, 'LexLib: ' + msg );
  halt( 1 );
End;

(* I/O routines: *)

Function TCustomLexer.get_char: TxNativeChar;
Var
  i: Integer;
Begin
  If ( bufptr = 0 ) And Not eof( yyinput ) Then
  Begin
    readln( yyinput, yyline );
    inc( yylineno );
    yycolno := 1;
    buf[1] := nl;
    For i := 1 To length( yyline ) Do
    begin
      buf[i + 1] := yyline[length( yyline ) - i + 1];
    end;
    inc( bufptr, length( yyline ) + 1 );
  End;
  If bufptr > 0 Then
  Begin
    get_char := buf[bufptr];
    dec( bufptr );
    inc( yycolno );
  End
  Else
    get_char := #0;
End;

Procedure TCustomLexer.unget_char( c: TxNativeChar );
Begin
  If bufptr = max_chars Then
    fatal( 'input buffer overflow' );
  inc( bufptr );
  dec( yycolno );
  buf[bufptr] := c;
End;

Procedure TCustomLexer.put_char( c: TxNativeChar );
Begin
  If c = #0 Then
    { ignore }
  Else If c = nl Then
    writeln( yyoutput, '' )
  Else
    write( yyoutput, c )
End;

(* Utilities: *)

Procedure TCustomLexer.echo;
Var
  i: Integer;
Begin
  for i := 1 to yyTextLen do
    put_char(yyTextBuf^ [i])
End;

Procedure TCustomLexer.yymore;
Begin
  //Fyystext := yytext;
  if yyTextBuf <> nil then
  begin
    if yyTextLen > 0 then
    begin
      SetLength (Fyystext, yyTextLen);
      Move (yyTextBuf^, Fyystext [1], yyTextLen);
    end else
      Fyystext:='';
  end
  else Fyystext := '';
End;

Procedure TCustomLexer.yyless( n: Integer );
Var
  i: Integer;
Begin
  for i := yytextlen downto n+1 do
    unget_char(yytextbuf^ [i]);
  CheckyyTextBuf (n);
  yyTextLen := n;
End;

function TCustomLexer.yylexinternal: Integer; {modified by fduenas: make TP Yacc/Lex thread safe)}
begin
 result := yylex(yylValInternal); {modified by fduenas: make TP Yacc/Lex thread safe)}
end;

Procedure TCustomLexer.reject;
Var
  i: Integer;
Begin
  yyreject := true;
  for i := yyTextLen + 1 to Fyysleng do
  begin
    Inc (yyTextLen);
    yyTextBuf^ [yyTextLen] := get_char;
    //yytext := yytext + get_char;
  end;
  dec( Fyymatches );
End;

Procedure TCustomLexer.returni( n: Integer );
Begin
  yyretval := n;
  yydone := true;
End;

Procedure TCustomLexer.returnc( c: TxNativeChar );
Begin
  yyretval := ord( c );
  yydone := true;
End;

Procedure TCustomLexer.start( state: Integer );
Begin
  Fyysstate := state;
End;

(* yywrap: *)

Function TCustomLexer.yywrap: Boolean;
Begin
  // ????? close(yyinput); close(yyoutput);
  yywrap := true;
End;

(* Internal routines: *)

Procedure TCustomLexer.yynew;
Begin
  If yylastchar <> #0 Then
    If yylastchar = nl Then
      Fyylstate := 1
    Else
      Fyylstate := 0;
  yystate := Fyysstate + Fyylstate;
  //yytext := Fyystext;
  CheckyyTextBuf (Length (Fyystext));
  yyTextLen := Length (Fyystext);
  if yyTextLen > 0 then
    Move (Fyystext [1], yytextbuf^, yyTextLen);

  Fyystext := '';
  Fyymatches := 0;
  yydone := false;
End;

Procedure TCustomLexer.yyscan;
Begin
  //if Length(yytext)=255 then fatal('yytext overflow');
  yyactchar := get_char;
  //yytext := yytext + yyactchar;
  CheckyyTextBuf (yyTextLen + 1);
  Inc (yyTextLen);
  yyTextBuf^ [yyTextLen] := yyactchar;
End;

Procedure TCustomLexer.yymark( n: Integer );
Begin
  If n > max_rules Then
    fatal( 'too many rules' );
  //Fyypos[n] := Length( yytext );
  Fyypos [n] := yyTextLen;
End;

Procedure TCustomLexer.yymatch( n: Integer );
Begin
  inc( Fyymatches );
  If Fyymatches > max_matches Then
    fatal( 'match stack overflow' );
  Fyystack[Fyymatches] := n;
End;

Function TCustomLexer.yyfind( Var n: Integer ): Boolean;
Begin
  yyreject := false;
  While ( Fyymatches > 0 ) And ( Fyypos[Fyystack[Fyymatches]] = 0 ) Do
    dec( Fyymatches );
  If Fyymatches > 0 Then
  Begin
    Fyysleng := yyTextLen;
    n := Fyystack[Fyymatches];
    yyless( Fyypos[n] );
    Fyypos[n] := 0;
    if yyTextLen >0 then
      yylastchar := yytextbuf^ [yytextlen]
    Else
      yylastchar := #0;
    yyfind := true;
  End
  Else
  Begin
    yyless( 0 );
    yylastchar := #0;
    yyfind := false;
  End
End;

Function TCustomLexer.yydefault: Boolean;
Begin
  yyreject := false;
  yyactchar := get_char;
  If yyactchar <> #0 Then
  Begin
    put_char( yyactchar );
    yydefault := true;
  End
  Else
  Begin
    Fyylstate := 1;
    yydefault := false;
  End;
  yylastchar := yyactchar;
End;

Procedure TCustomLexer.yyclear;
Begin
  bufptr := 0;
  Fyysstate := 0;
  Fyylstate := 1;
  yylastchar := #0;
  yyTextLen := 0;
  Fyystext := '';
End;

constructor TCustomLexer.Create;
begin
  inherited Create;
  CheckyyTextBuf (intial_bufsize);
  CheckBuffer (intial_bufsize);
end;

destructor TCustomLexer.Destroy;
begin
  FreeMem (FBuf);
  FreeMem (yyTextBuf);
  inherited;
end;

procedure TCustomLexer.CheckBuffer(Index : integer);
begin
  repeat
    if Index > BufSize then
    begin
      bufSize := max (bufSize * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}, intial_bufsize); {changed bye fduenas, 2 to SizeOf(Char)}
      ReallocMem (FBuf, bufSize);
    end;
  until Index <= bufSize;
end;

function TCustomLexer.GetBuf(Index: Integer): TxNativeChar;
begin
  CheckBuffer (Index);
  Result := FBuf^ [Index];
end;

procedure TCustomLexer.SetBuf(Index: Integer; Value: TxNativeChar);
begin
  CheckBuffer (Index);
  FBuf^ [Index] := Value;
end;

procedure TCustomLexer.CheckyyTextBuf(Size : integer);
begin
  repeat
    if Size > yyTextBufSize then
    begin
      yyTextBufSize := max (yyTextBufSize * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}, intial_bufsize); {changed bye fduenas, 2 to SizeOf(Char)}
      ReallocMem (yyTextBuf, yyTextBufSize);
    end;
  until Size <= yyTextBufSize;
end;

procedure TCustomLexer.GetyyText(var s : TxNativeString);
begin
  if yyTextLen > 0 then
  begin
    SetLength (s, yyTextLen);
    Move (yytextbuf^, s[1], yyTextLen * {$IFNDEF XQ_USE_SIZEOF_CONSTANTS}SizeOf(TxNativeChar){$ELSE}XQ_SizeOf_NativeChar{$ENDIF}); { patched by ccy }
  end
  else
    s:= '';
end;

End.
