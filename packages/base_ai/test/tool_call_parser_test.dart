import 'package:base_ai/base_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tools = {'search_talks', 'calculate'};

  test('fenced JSON from the prompt format', () {
    final r = ToolCallParser.parse('Sure.\n```tool_call\n{"name": "search_talks", "arguments": {"query": "budget"}}\n```', tools);
    expect(r.calls.single.name, 'search_talks');
    expect(r.calls.single.arguments['query'], 'budget');
    expect(r.text, 'Sure.');
  });

  test('FunctionGemma and python styles', () {
    expect(
      ToolCallParser.parse('<start_function_call>call:search_talks{query:<escape>a, b<escape>}<end_function_call>', tools).calls.single.arguments,
      {'query': 'a, b'},
    );
    expect(ToolCallParser.parse('[calculate(expression="2*3")]', tools).calls.single.arguments['expression'], '2*3');
  });

  test('ignores unknown tools and plain text', () {
    expect(ToolCallParser.parse('```json\n{"name": "rm_rf", "arguments": {}}\n```', tools).calls, isEmpty);
    expect(ToolCallParser.parse('Just an answer.', tools).calls, isEmpty);
  });

  test('the prompt lists the tools and the call format', () {
    final p = ToolCallParser.prompt([const ToolSpec(name: 'search_talks', description: 'Search talks', parameters: {})]);
    expect(p, contains('search_talks'));
    expect(p, contains('```tool_call'));
  });
}
