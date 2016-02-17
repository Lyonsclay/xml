defmodule XML do
  @moduledoc """
  An XML document parser designed for retrieving data from an XML API response.

  Wraps a subset of Erlang's xmerl module.
  http://erlang.org/doc/man/xmerl.html
  """

  import Record

  @doc """
  Import the xmlElement record from xmerl.

  It is the type that is returned when xmerl parses an XML document. It can be
  navigated with the xmerl xpath function. It has the following spec from the
  Erlang documentation.

  %% XML Element
  %% content = [#xmlElement()|#xmlText()|#xmlPI()|#xmlComment()|#xmlDecl()]
  -record(xmlElement,{
      name,      % atom()
      expanded_name = [],  % string() | {URI,Local} | {"xmlns",Local}
      nsinfo = [],          % {Prefix, Local} | []
      namespace=#xmlNamespace{},
      parents = [],    % [{atom(),integer()}]
      pos,      % integer()
      attributes = [],  % [#xmlAttribute()]
      content = [],
      language = "",  % string()
      xmlbase="",           % string() XML Base path, for relative URI:s
      elementdef=undeclared % atom(), one of [undeclared | prolog | external | element]
    }).
  """
  defrecord :xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")

  @doc """
  Import the xmlText record from xmerl.

  It is the type that is returned when accessing the content attribute of
  an :xmlElement. It has the following spec from the Erlang documentation.

  %% plain text
  %% IOlist = [char() | binary () | IOlist]
  -record(xmlText,{
      parents = [],  % [{atom(),integer()}]
      pos,    % integer()
      language = [],% inherits the element's language
      value,  % IOlist()
      type = text   % atom() one of (text|cdata)
    }).
  """
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  @typedoc """
  Erlang xmerl xmlElement.
  """
  @type xml_element :: :xmlElement

  @typedoc """
  Erlang xmerl xmlText.
  """
  @type xml_text :: :xmlText

  @typedoc """
  Represents an XML tag name.

  It can be either a string, a char list or an atom.
  """
  @type tag :: String.t | list | atom

  @typedoc """
  Raw XML data in the form of a string or char list.
  """
  @type xml :: String.t | list
  defmacro is_xml(xml) do
    quote do: is_bitstring(unquote(xml)) or is_list(unquote(xml))
  end

  @doc """
  Parses an XML document.

  It will take a char list or string representation of an XML document.  It
  returns an xmlElement that can be used for accessing values.

  Some schema validation occurs. If there is a DTD it will be strictly
  evaluated. If an error is ecnountered the process will exit and pass a
  message.

  ## Examples

    iex>XML.parse('<tag>value</tag>')
    {:xmlElement, :tag, :tag, [], {:xmlNamespace, [], []}, [], 1, [],
    [{:xmlText, [tag: 1], 1, [], 'value', :text}], [],
    '.', :undeclared }

    iex>XML.parse("<tag>value</tag>")
    {:xmlElement, :tag, :tag, [], {:xmlNamespace, [], []}, [], 1, [],
    [{:xmlText, [tag: 1], 1, [], 'value', :text}], [],
    '.', :undeclared }

    iex>try do
    ...>  XML.parse('<tag>value</stag>')
    ...>catch
    ...>  :exit, message ->
    ...>    message
    ...>end
    {:fatal, {{:endtag_does_not_match, {:was, :stag, :should_have_been,
    :tag}}, {:file, :file_name_unknown}, {:line, 1}, {:col, 14}}}
  """

  @spec parse(list) :: xml_element
  def parse(xml) when is_list(xml) do
    { parsed_xml, _ } = :xmerl_scan.string(xml)
    strip_path_data(parsed_xml)
  end
  @spec parse(String.t) :: xml_element
  def parse(xml) when is_bitstring(xml) do
    { parsed_xml, _ } = :xmerl_scan.string(:binary.bin_to_list(xml))
    strip_path_data(parsed_xml)
  end

  @doc """
  Returns value(s) associated with `tag` in `xml_element`.

  It takes either a parsed `xml_element` or `xml`(raw XML), and a `tag` to
  search for. A list of matching value(s) in the respective `xml` type will be
  returned.

  Both the `xml` and the `tag` will be assesed for corectness. If an invalid
  character is used in the `tag` it will exit with an :invalid_name error.

  ## Examples

      iex>XML.get('<bag>cat</bag>', 'bag')
      ['cat']

      iex>element = XML.parse('<bag>cat</bag>')
      ...>XML.get(element, 'bag')
      ['cat']

      iex>element = XML.parse('<bag>cat</bag>')
      ...>XML.get(element, "bag")
      ["cat"]

      iex>element = XML.parse('<bag>cat</bag>')
      ...>XML.get(element, :bag)
      [:cat]

      iex>element = XML.parse('<bag>cat</bag>')
      ...>try do
      ...>  XML.get(element, '/bag')
      ...>catch
      ...>  :exit, message ->
      ...>    message
      ...>end
      {:fatal, {{:invalid_name, '/bag><'}, {:file, :file_name_unknown}, {:line,
      1}, {:col, 2}}}
  """
  @spec get(xml, tag) :: list | String.t 
  def get(xml, tag) when is_xml(xml) do
    parse(xml)
    |> get(tag)
  end
  @spec get(xml_element, tag) :: list | String.t
  def get(xml_element, tag) when is_list(tag) do
    _get(xml_element, tag)
  end
  def get(xml_element, tag) when is_bitstring(tag) do
    _get(xml_element, String.to_char_list(tag))
    |> Enum.map(&(List.to_string(&1)))
  end
  def get(xml_element, tag) when is_atom(tag) do
    _get(xml_element, Atom.to_char_list(tag))
    |> Enum.map(&(List.to_atom(&1)))
  end


  @doc """
  Evaluate and `xml_element` with an XPath expression.

  It takes an XPath expression in the form of char list or string, and returns a
  list of any matching values in the respective type. If the expression uses
  characters that are not permitted by Xpath it will exit with :invalid_name
  error.

  ## Examples
      iex>element = XML.parse('<fun><bag>cat</bag><bag>brown</bag></fun>')
      iex>XML.xpath(element, '/bag') 
      [] 
      iex>XML.xpath(element, '/fun/bag')
      ['cat', 'brown']
  """
  @spec xpath(xml_element, list) :: list
  def xpath(xml_element, path) when is_list(path) do
    _xpath(xml_element, path)
    |> content
    |> text_value
  end
  def xpath(xml_element, path) when is_bitstring(path) do
    _xpath(xml_element, String.to_char_list(path))
    |> content
    |> text_value
    |> Enum.map(&(List.to_string(&1)))
  end

  @spec _get(xml_element, tag) :: list
  defp _get(xml_element, tag) do
    check_tag(tag)
    _xpath(xml_element, '//' ++ tag )
    |> content
    |> text_value
  end

  @spec _xpath(xml_element, list) :: [xml_element]
  defp _xpath(xml_element, xpath) do
    :xmerl_xpath.string(xpath, xml_element)
  end

  @spec content([xml_element]) :: [xml_text]
  defp content(xml_element) do
    Enum.flat_map(xml_element, &(xmlElement(&1, :content)))
  end

  @spec text_value(xml_text) :: [String.t]
  defp text_value(xml_text) do
    Enum.map(xml_text, &(xmlText(&1, :value)))
  end

  # Remove path data from xml_element xml_base attribute for easy testing and
  # interpretation.
  @spec strip_path_data(xml_element) :: xml_element
  defp strip_path_data(xml_element) do
    if elem(xml_element, 10) == cwd do
      put_elem(xml_element, 10, '.')
    else
      xml_element
    end
  end

  # Use :xmerl_scan to check if tag name is valid.
  @spec check_tag(tag) :: xml_element | :exit
  defp check_tag(tag) do
    :xmerl_scan.string('<#{tag}></#{tag}>')
  end

  @spec cwd :: list
  defp cwd do
    String.to_char_list(Path.absname(''))
  end
end
