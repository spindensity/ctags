#
# Makefile for Windows using MSVC and vcpkg
#
# To use from the command line:
# 1. From the Start Menu "Visual Studio 2019" -> "x64 Native Tools Command Prompt for VS 2019"
# 2. In the command prompt that opens goto the directory containing the sources
# 3. Install dependencies: vcpkg install libiconv:x64-windows-static libyaml:x64-windows-static libxml2:x64-windows-static jansson:x64-windows-static
# 4. Execute: nmake -f mk_mvc_vcpkg.mak VCPKG_ROOT=/path/to/vcpkg
#

include source.mak

REGEX_DEFINES = -DHAVE_REGCOMP -D__USE_GNU -DHAVE_STDBOOL_H -Dstrcasecmp=stricmp

OBJEXT = obj
COMMON_DEFINES =
DEFINES = -DWIN32 $(REGEX_DEFINES) -DHAVE_PACKCC $(COMMON_DEFINES) -DHAVE_REPOINFO_H
INCLUDES = -I. -Imain -Ignu_regex -Ifnmatch -Iparsers -Ilibreadtags
OPT = /O2 /WX /MT /utf-8 /arch:AVX2
PACKCC = packcc.exe
REGEX_OBJS = $(REGEX_SRCS:.c=.obj)
FNMATCH_OBJS = $(FNMATCH_SRCS:.c=.obj)
WIN32_OBJS = $(WIN32_SRCS:.c=.obj)
PEG_OBJS = $(PEG_SRCS:.c=.obj)
PACKCC_OBJS = $(PACKCC_SRCS:.c=.obj)
RES_OBJ = win32/ctags.res
ALL_OBJS = $(ALL_SRCS:.c=.obj) $(REGEX_OBJS) $(FNMATCH_OBJS) $(WIN32_OBJS) $(PEG_OBJS) $(RES_OBJ)
READTAGS_OBJS = $(READTAGS_SRCS:.c=.obj)

# Use vcpkg to support extra features:
INCLUDES = /I$(VCPKG_ROOT)/installed/x64-windows-static/include $(INCLUDES)

DEFINES = $(DEFINES) -DHAVE_ICONV
LIBS = $(LIBS) /libpath:$(VCPKG_ROOT)/installed/x64-windows-static/lib iconv.lib charset.lib

DEFINES = $(DEFINES) -DHAVE_LIBYAML=1 -DYAML_DECLARE_STATIC
LIBS = $(LIBS) /libpath:$(VCPKG_ROOT)/installed/x64-windows-static/lib yaml.lib
PARSER_SRCS = $(PARSER_SRCS) $(YAML_SRCS)
PARSER_HEADS = $(PARSER_HEADS) $(YAML_HEADS)

DEFINES = $(DEFINES) -DHAVE_LIBXML=1
LIBS = $(LIBS) /libpath:$(VCPKG_ROOT)/installed/x64-windows-static/lib libxml2.lib lzma.lib zlib.lib ws2_32.lib
PARSER_SRCS = $(PARSER_SRCS) $(XML_SRCS)
PARSER_HEADS = $(PARSER_HEADS) $(XML_HEADS)

DEFINES = $(DEFINES) -DHAVE_JANSSON=1
LIBS = $(LIBS) /libpath:$(VCPKG_ROOT)/installed/x64-windows-static/lib jansson.lib

!ifdef DEBUG
DEFINES = $(DEFINES) -DDEBUG
PDB = yes
!endif

!ifdef PDB
OPT = $(OPT) /Zi
PDBFLAG = /debug
!else
PDBFLAG =
!endif

# Generate repoinfo.h.
!if [win32\gen-repoinfo.bat $(REPOINFO_HEADS)]
!endif

.SUFFIXES: .peg

{main}.c{main}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Fomain\ /c $<
{optlib}.c{optlib}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Fooptlib\ /c $<
{parsers}.c{parsers}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Foparsers\ /c $<
{parsers\cxx}.c{parsers\cxx}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Foparsers\cxx\ /c $<
{extra-cmds}.c{extra-cmds}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Foextra-cmds\ /c $<
{libreadtags}.c{libreadtags}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Folibreadtags\ /c $<
{win32\mkstemp}.c{win32\mkstemp}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Fowin32\mkstemp\ /c $<
{peg}.peg{peg}.c::
	$(PACKCC) -i \"general.h\" $<
{peg}.c{peg}.obj::
	$(CC) $(OPT) $(DEFINES) $(INCLUDES) /Fopeg\ /c $<

all: $(PACKCC) ctags.exe readtags.exe

ctags: ctags.exe

ctags.exe: $(ALL_OBJS) $(ALL_HEADS) $(PEG_HEADS) $(PEG_EXTRA_HEADS) $(REGEX_HEADS) $(FNMATCH_HEADS) $(WIN32_HEADS) $(REPOINFO_HEADS)
	$(CC) $(OPT) /Fe$@ $(ALL_OBJS) /link setargv.obj $(LIBS) $(PDBFLAG)

readtags.exe: $(READTAGS_OBJS) $(READTAGS_HEADS) $(REGEX_OBJS) $(REGEX_HEADS)
	$(CC) $(OPT) /Fe$@ $(READTAGS_OBJS) $(REGEX_OBJS) /link setargv.obj $(PDBFLAG)

$(REGEX_OBJS): $(REGEX_SRCS)
	$(CC) /c $(OPT) /Fo$@ $(INCLUDES) $(DEFINES) $(REGEX_SRCS)

$(FNMATCH_OBJS): $(FNMATCH_SRCS)
	$(CC) /c $(OPT) /Fo$@ $(INCLUDES) $(DEFINES) $(FNMATCH_SRCS)

$(PACKCC_OBJS): $(PACKCC_SRCS)
	$(CC) /c $(OPT) /Fo$@ $(INCLUDES) $(COMMON_DEFINES) $(PACKCC_SRCS)

$(PACKCC): $(PACKCC_OBJS)
	$(CC) $(OPT) /Fe$@ $(PACKCC_OBJS) /link setargv.obj $(PDBFLAG)

main\repoinfo.obj: main\repoinfo.c main\repoinfo.h

peg\varlink.c peg\varlink.h: peg\varlink.peg $(PACKCC)

$(RES_OBJ): win32/ctags.rc win32/ctags.exe.manifest win32/resource.h
	$(RC) /nologo /l 0x409 /Fo$@ $*.rc


clean:
	- del *.obj main\*.obj optlib\*.obj parsers\*.obj parsers\cxx\*.obj gnu_regex\*.obj fnmatch\*.obj misc\packcc\*.obj peg\*.obj extra-cmds\*.obj libreadtags\*.obj win32\mkstemp\*.obj win32\*.res main\repoinfo.h
	- del ctags.exe readtags.exe $(PACKCC)
	- del tags
