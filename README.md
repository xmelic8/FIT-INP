Projekty do předmětu INP na VUT FIT ve školním roce 2013/2014

Hodnocení 

proj1: 13/13b

proj2: 20/12b

komentář: 
Odevzdane soubory:

  cpu.vhd ano
  login.b ano
  inp.png ano
  inp.srp ano

Overeni cinnosti kodu CPU:
  #   testovany program (BF)        vysledek
  1.  ++++++++++                    ok
  2.  ----------                    ok
  3.  +>++>+++                      ok
  4.  <+<++<+++                     ok
  5.  .+.+.+.                       ok
  6.  ,+,+,+,                       ok
  7.  [........]test[.........]     chyba
  8.  +++[.-]                       ok
  9.  +++++[>++[>+.<-]<-]           chyba

  Podpora jednoduchych cyklu: ano
  Podpora vnorenych cyklu: ne

Poznamky k implementaci:
  Nekompletni sensitivity list; chybejici signaly: DATA_RDATA, IN_VLD, ireg_reg
  Mozne problematicke rizeni nasledujicich signalu: DATA_RDWR, IN_REQ, OUT_DATA, SEL
