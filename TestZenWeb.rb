#!/usr/local/bin/ruby -w

$TESTING = TRUE

require 'ZenWeb'
require 'runit/testcase'

class ZenTest < RUNIT::TestCase

  def setup
    @datadir = "test"
    @htmldir = "testhtml"
    @sitemapUrl = "/SiteMap.html"
    @url = "/~ryand/index.html"
    @web = ZenWebsite.new(@sitemapUrl, @datadir, @htmldir)
    @doc = ZenDocument.new(@url, @web)
    @content = @doc.renderContent
  end

  def teardown
    if (test(?d, @htmldir)) then
      #`rm -rf #{@htmldir}` unless $DEBUG
    end
  end

end

############################################################
# ZenWebsite:

class TestZenWebsite < ZenTest

  def teardown
    if (test(?d, @htmldir)) then
      #`rm -rf #{@htmldir}` unless $DEBUG
    end
  end

  def test_initialize1
    begin
      @web = ZenWebsite.new("/doesn't exist", @datadir, @htmldir)
    rescue
      assert_equals("ArgumentError", $!.class.to_s)
    else
      assert(FALSE, "Bad url should throw exception")
    end
  end

  def test_initialize2
    begin
      @web = ZenWebsite.new(@sitemapUrl, "/doesn't exist", @htmldir)
    rescue
      assert_equals("ArgumentError", $!.class.to_s)
    else
      assert(FALSE, "Bad datadir should throw exception")
    end
    
  end

  def test_initialize3
    # missing a leading slash
    begin
      @web = ZenWebsite.new("SiteMap.html", @datadir, @htmldir)
    rescue
      assert_equals("ArgumentError", $!.class.to_s)
    else
      assert(FALSE, "Bad url should throw exception")
    end
    
  end

  def util_checkContent(path, expected)
    assert(test(?f, path),
	   "File '#{path}' must exist")
    file = IO.readlines(path).join('')
    assert_not_nil(file.index(expected),
	   "File '#{path}' must have correct content")
  end

  def test_render

    @web.renderSite

    assert(test(?d, @htmldir),
	   "HTML directory must be created by renderSite")

    util_checkContent(@htmldir + "/index.html",
		      "this is the url: /index.html")

    util_checkContent(@htmldir + "/SiteMap.html",
		      "/~ryand/stuff/index.html")

    util_checkContent(@htmldir + "/Something.html",
		      "this is the url: /Something.html")

    util_checkContent(@htmldir + "/ryand/index.html",
		      "Everything is separated by paragraphs")

    util_checkContent(@htmldir + "/ryand/blah.html",
		      "this is the url: /~ryand/blah.html")

    util_checkContent(@htmldir + "/ryand/stuff/index.html",
		      "this is the url: /~ryand/stuff/index.html")

  end

  def test_index_accessor
    assert_not_nil(@web[@sitemapUrl],
		   "index accessor must return the sitemap")
    assert_nil(@web["doesn't exist"],
	       "index accessor must return nil for bad urls")
  end

end

############################################################
# ZenDocument

class TestZenDocument < ZenTest

  def setup
    super
    @expected_datapath = "test/ryand/index"
    @expected_htmlpath = "testhtml/ryand/index.html"
    @expected_dir = "test/ryand"
    @expected_subpages = [ '/~ryand/blah.html', '/~ryand/stuff/index.html' ]
  end

  def test_initialize1
    # good url
    begin
      ZenDocument.new("/Something.html", @web)
    rescue
      assert(FALSE, "good url must not throw an exception")
    else
      # this is good.
    end
  end

  def test_initialize2
    # missing extension
    begin
      ZenDocument.new("/Something", @web)
    rescue
      assert(FALSE, "missing extension must not throw an exception")
    else
      # this is good
    end
  end

  def test_initialize3
    # missing slash url
    begin
      ZenDocument.new("Something.html", @web)
    rescue ArgumentError
      # this is good
    rescue
      assert(FALSE, "missing slash produced the wrong type of exception")
    else
      assert(FALSE, "missing slash should have thrown an exception")
    end
  end

  def test_initialize4
    # bad url
    begin
      ZenDocument.new("/missing.html", @web)
    rescue ArgumentError
      # this is good
    rescue
      assert(FALSE, "missing document produced the wrong type of exception")
    else
      assert(FALSE, "missing document should have thrown an exception")
    end
  end

  def test_initialize5
    # missing slash url
    begin
      ZenDocument.new("/Something.html", nil)
    rescue ArgumentError
      # this is good
    rescue
      assert(FALSE, "nil website produced the wrong type of exception")
    else
      assert(FALSE, "nil website should have thrown an exception")
    end
  end

  def test_subpages
    @web.renderSite
    @doc = @web[@url]
    assert_equals(@expected_subpages,
		  @doc.subpages.sort)
  end

  def test_render
    file = @doc.htmlpath
    if (test(?f, file)) then
      File.delete(file)
    end

    @doc.render

    assert(test(?f, file), "document must render in correct location")
  end

  def test_renderContent_bad
    @doc = @web[@sitemapUrl]
    @doc['renderers'] = [ 'NonExistantRenderer' ]

    begin
      @doc.renderContent
    rescue Exception
      assert_equals("NotImplementedError", $!.class.name,
		    "renderContent must throw a NotImplementError.")
    else
      assert(FALSE,
	     "renderContent must throw an exception if renderer doesn't exist")
    end
  end

  def test_parentURL
    # 1 level deep
    @doc = ZenDocument.new("/Something.html", @web)
    assert_equals("/index.html", @doc.parentURL())

    # 2 levels deep - index
    @doc = ZenDocument.new("/ryand/index.html", @web)
    assert_equals("/index.html", @doc.parentURL())

    # 2 levels deep
    # yes, using metadata.txt is cheating, but it is a valid file...
    @doc = ZenDocument.new("/ryand/metadata.txt", @web)
    assert_equals("/ryand/index.html", @doc.parentURL())

    # 1 levels deep with a tilde
    @doc = ZenDocument.new("/~ryand/index.html", @web)
    assert_equals("/index.html", @doc.parentURL())

    # 2 levels deep with a tilde
    @doc = ZenDocument.new("/~ryand/stuff/index.html", @web)
    assert_equals("/~ryand/index.html", @doc.parentURL())
  end

  def test_createList1

    assert_equal(["line 1", "line 2"],
		 @doc.createList("line 1\nline 2\n"))
  end

  def test_createList2

    assert_equals([ "line 1", 
		    [ "line 1.1", "line 1.2" ], 
		    "line 2", 
		    [ "line 2.1",
		      [ "line 2.1.1" ] ] ],
		  @doc.createList("line 1\n\tline 1.1\n\tline 1.2\n" +
				  "line 2\n\tline 2.1\n\t\tline 2.1.1"))
  end

  def test_createHash1
    assert_equal({"term 1" => "def 1", "term 2" => "def 2"},
		 @doc.createHash("%- term 1\n%= def 1\n%-term 2\n%=def 2"))
  end

  def test_parent
    parent = @doc.parent

    assert_not_nil(parent,
		   "Parent must not be nil")

    assert_equal("/index.html", parent.url,
		 "Parent url must be correct")
  end

  def test_dir
    assert_equals(@expected_dir, @doc.dir)
  end

  def test_datapath
    assert_equals(@expected_datapath, @doc.datapath)
  end

  def test_htmlpath
    assert_equals(@expected_htmlpath, @doc.htmlpath)
  end

end

############################################################
# ZenSitemap

class TestZenSitemap < TestZenDocument

  def setup
    super
    @url = @sitemapUrl
    @web = ZenWebsite.new(@url, "test", "testhtml")
    @doc = @web[@url]
    @content = @doc.renderContent

    @expected_datapath = "test/SiteMap"
    @expected_dir = "test"
    @expected_htmlpath = "testhtml/SiteMap.html"
    @expected_subpages = []

    @expected_docs = ([ "/index.html",
			"/SiteMap.html",
			"/Something.html",
			"/~ryand/index.html",
			"/~ryand/blah.html",
			"/~ryand/stuff/index.html"])
  end

  def test_documents
    docs = @doc.documents

    @expected_docs.each { | url |
      assert(docs.has_key?(url),
	     "Sitemap's documents must include #{url}")

      assert_equal(url != "/SiteMap.html" ? ZenDocument : ZenSitemap,
		   docs[url].class,
		   "Document #{url} must be the correct class")
    }
  end

  def test_doc_order
    assert_equal(@expected_docs,
		 @doc.doc_order,
		 "Sitemap's document order must be correct")
  end

  def test_sitemap_content
    expected = "<H2>There are 6 pages in this website.</H2>\n<HR SIZE=\"3\" NOSHADE>\n\n<UL>\n  <LI><A HREF=\"/index.html\">My Homepage: Subtitle</A></LI>\n  <LI><A HREF=\"/SiteMap.html\">Sitemap: There are 6 pages in this website.</A></LI>\n  <LI><A HREF=\"/Something.html\">Something</A></LI>\n  <LI><A HREF=\"/~ryand/index.html\">Ryan's Homepage: Version 2.0</A></LI>\n  <UL>\n    <LI><A HREF=\"/~ryand/blah.html\">blah</A></LI>\n    <LI><A HREF=\"/~ryand/stuff/index.html\">my stuff</A></LI>\n  </UL>\n</UL>"

    assert_not_nil(@content.index(expected) > 0,
		   "Must render some form of HTML")
  end
end

class TestGenericRenderer < ZenTest

  def test_initialize
    # TODO: def initialize(document)
  end

  def test_push
    # TODO: def push(obj)
  end

  def test_unshift
    # TODO: def unshift(obj)
  end

  def test_render
    # TODO: def render(content)
  end

  def test_access
    # TODO: def [](key)
  end
end

class TestHtmlRenderer < ZenTest

  def setup
    super
    @renderer = HtmlRenderer.new(@doc)
  end

  def test_array2html1
    assert_equal("<UL>\n  <LI>line 1</LI>\n  <LI>line 2</LI>\n</UL>\n",
		 @renderer.array2html(["line 1", "line 2"]))
  end

  def test_array2html2

    assert_equal("<UL>\n  <LI>line 1</LI>\n  <UL>\n    <LI>line 1.1</LI>\n    <LI>line 1.2</LI>\n  </UL>\n  <LI>line 2</LI>\n  <UL>\n    <LI>line 2.1</LI>\n    <UL>\n      <LI>line 2.1.1</LI>\n    </UL>\n  </UL>\n</UL>\n",
		 @renderer.array2html([ "line 1", 
					[ "line 1.1", "line 1.2" ], 
					"line 2", 
					[ "line 2.1",
					  [ "line 2.1.1" ] ] ]))
  end

  def test_hash2html
    # FIX: needs a test
  end

end

class TestHtmlTemplateRenderer < ZenTest

  def test_renderContent_html_and_head
    assert_not_nil(@content.index("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\">
<HTML>
<HEAD>
<TITLE>Ryan's Homepage: Version 2.0</TITLE>
<LINK REV=\"MADE\" HREF=\"mailto:ryand-web@zenspider.com\">
<META NAME=\"rating\" CONTENT=\"general\">
<META NAME=\"GENERATOR\" CONTENT=\"ZenWeb 2.1.0\">
<META NAME=\"author\" CONTENT=\"Ryan Davis\">
<META NAME=\"copyright\" CONTENT=\"1996-2001, Zen Spider Software\">
</HEAD>
<BODY>
<P>
<A HREF=\"/SiteMap.html\"><STRONG>Sitemap</STRONG></A> || <A HREF=\"/index.html\">My Homepage</A>
 / Ryan's Homepage</P>
<H1>Ryan's Homepage</H1>
<H2>Version 2.0</H2>
<HR SIZE=\"3\" NOSHADE>"),
	   "Must render the HTML header and all appropriate metadata")
  end

  def test_renderContent_foot
    assert(@content =~ %r,</BODY>\n</HTML>\n,,
	   "Must render HTML footer")
  end

end

class TestTextToHtmlRenderer < ZenTest

  def test_renderContent_headers
    assert(@content =~ %r,<H2>Head 2</H2>,,
	   "Must render H2 from **")

    assert(@content =~ %r,<H3>Head 3</H3>,,
	   "Must render H3 from ***")

    assert(@content =~ %r,<H4>Head 4</H4>,,
	   "Must render H4 from ****")

    assert(@content =~ %r,<H5>Head 5</H5>,,
	   "Must render H5 from *****")

    assert(@content =~ %r,<H6>Head 6</H6>,,
	   "Must render H6 from ******")

  end

  def test_renderContent_list1

    assert_not_nil(@content.index("<UL>\n  <LI>Lists (should have two items).</LI>\n  <LI>Continuted Lists.</LI>\n</UL>"),
	   "Must render normal list from +")
  end

  def test_renderContent_list2
    assert_not_nil(@content.index("<UL>\n  <LI>Another List (should have a sub list).</LI>\n  <UL>\n    <LI>With a sub-list</LI>\n    <LI>another item</LI>\n  </UL>\n</UL>"),
	   "Must render compound list from indented +'s")
  end

  def test_renderContent_dict1
    assert_not_nil(@content.index("<DL>\n  <DT>Term 1</DT>\n  <DD>Def 1</DD>\n\n  <DT>Term 2</DT>\n  <DD>Def 2</DD>\n\n</DL>\n\n"),
		   "Must render simple dictionary list")
  end

  def test_renderContent_metadata
    assert(@content =~ %r,Glossary lookups for 42 and some string \(see metadata.txt for a hint\)\.\s+key99 should not look up\.,,
	   "Must render metadata lookups from \#\{key\}")
  end

  def test_renderContent_small_rule
    assert(@content =~ %r,^<HR SIZE="1" NOSHADE>$,,
	   "Must render small rule from ---")
  end

  def test_renderContent_big_rule
    assert(@content =~ %r,^<HR SIZE="2" NOSHADE>$,,
	   "Must render big rule from ===")
  end

  def test_renderContent_paragraph1
    assert(@content =~ %r,^<P>Paragraphs can contain <A HREF="http://www\.ZenSpider\.com/ZSS/ZenWeb/">www\.ZenSpider\.com /ZSS /ZenWeb</A> and <A HREF="mailto:zss@ZenSpider\.com">zss@ZenSpider\.com</A> and they will automatically be converted\..*?</P>$,,
	   "Must render paragraph from a single line")
  end

  def test_renderContent_paragraph2
    assert(@content =~ %r;^<P>Likewise, two lines side by side\s+are considered one paragraph\..*?</P>$;,
	   "Must render paragraph from multiple lines")
  end

  def test_renderContent_paragraph3
     assert(@content =~ %r@Don\'t forget less-than "&lt;" &amp; greater-than "&gt;", but only if backslashed.</P>$@,
	   "Must convert special entities")
  end

  def test_renderContent_paragraph4
    assert(@content =~ %r;Supports <I>Embedded HTML</I>\.</P>$;,
	   "Must render paragraph from multiple lines")
  end

  def test_renderContent_paragraph5
    assert(@content =~ %r;Supports <A HREF=\"http://www.yahoo.com\">Unaltered urls</A> as well\.</P>$;,
	   "Must render full urls without conversion")
  end

  def test_renderContent_pre

    assert_not_nil(@content.index("<PRE>PRE blocks are paragraphs that are indented two spaces on each line.
The two spaces will be stripped, and all other indentation will be left
alone.
   this allows me to put things like code examples in and retain
       their formatting.</PRE>"),
	   "Must render PRE blocks from indented paragraphs")
  end

  def test_navbar
    # TODO: def navbar
  end
end

class TestFooterRenderer < ZenTest
  def test_render
    @doc = ZenDocument.new("/index.html", @web)
    @doc.content = [ "line 1\nline 2\nline 3\n" ]
    @doc['footer'] = "footer 1\n";
    @doc['renderers'] = [ 'FooterRenderer' ]

    content = @doc.renderContent

    assert_equals("line 1\nline 2\nline 3\nfooter 1\n", content)
  end
end

class TestHeaderRenderer < ZenTest
  def test_render
    @doc = ZenDocument.new("/index.html", @web)
    @doc.content = [ "line 1\nline 2\nline 3\n" ]
    @doc['header'] = "header 1\n";
    @doc['renderers'] = [ 'HeaderRenderer' ]

    content = @doc.renderContent

    assert_equals("header 1\nline 1\nline 2\nline 3\n", content)
  end
end

############################################################
# Metadata

class TestMetadata < RUNIT::TestCase

  def setup
    @file = "hash." + $$.to_s
    @hash = Metadata.new("test/ryand")
  end

  def teardown
    if (test(?f, @file)) then
      File.unlink(@file)
    end
  end

  def test_initialize1
    begin
      @hash = Metadata.new("test/ryand", "/")
    rescue
      assert_fail("Good init shall not throw an exception")
    else
      # this is good
    end
  end

  def test_initialize2
    assert_exception(ArgumentError, "bad path shall throw an ArgumentError") {
      @hash = Metadata.new("bad_path", "/")
    }
  end

  def test_initialize3
    assert_exception(ArgumentError, "bad top shall throw an ArgumentError") {
      @hash = Metadata.new("test/ryand", "somewhereelse")
    }
  end

  def test_initialize4
    assert_exception(ArgumentError, "deeper top shall throw an ArgumentError") {
      @hash = Metadata.new("test/ryand", "test/ryand/stuff")
    }
  end

  def test_save
    # TODO: def save(file)
  end

  def test_loadFromDirectory
    # TODO: def loadFromDirectory(directory, toplevel, count = 1)
  end

  def test_load
    # TODO: def load(file)
  end

  def test_core
    # this asserts that the values in the child are correct.
    assert_equal(42, @hash["key1"])
    assert_equal("some string", @hash["key2"])
    assert_equal("another string", @hash["key3"])
  end

  def test_parenthood
    # this is defined in the parent, but not the child
    assert_equal([ 'TextToHtmlRenderer', 'HtmlTemplateRenderer' ],
		 @hash["renderers"])
  end

end

############################################################
# The Test Suite:

class TestAll 
  def TestAll.suite
    suite = RUNIT::TestSuite.new

    suite.add_test(TestZenWebsite.suite)
    suite.add_test(TestZenDocument.suite)
    suite.add_test(TestZenSitemap.suite)
    suite.add_test(TestGenericRenderer.suite)
    suite.add_test(TestHtmlRenderer.suite)
    suite.add_test(TestHtmlTemplateRenderer.suite)
    suite.add_test(TestTextToHtmlRenderer.suite)
    suite.add_test(TestFooterRenderer.suite)
    suite.add_test(TestHeaderRenderer.suite)
    suite.add_test(TestMetadata.suite)

    return suite
  end
end

############################################################
# Main:

if __FILE__ == $0
  require 'runit/cui/testrunner'

  unless ($DEBUG) then
    suite = TestAll.suite
  else
    suite = RUNIT::TestSuite.new
    suite.add_test(TestZenDocument.new("test_parent", "TestZenDocument"))
  end

  RUNIT::CUI::TestRunner.run(suite)
end
