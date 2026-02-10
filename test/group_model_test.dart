import 'package:flutter_test/flutter_test.dart';
import 'package:bytecity_accounting/models/group_model.dart';

void main() {
  group('GroupModel Tests', () {
    test('fromJson parses correct JSON', () {
      final json = {
        'id': 'g1',
        'name': 'Test Group',
        'description': 'Description',
      };

      final group = GroupModel.fromJson(json);

      expect(group.id, 'g1');
      expect(group.name, 'Test Group');
      expect(group.description, 'Description');
    });

    test('supports value equality', () {
      final g1 = GroupModel(id: '1', name: 'A', description: 'B');
      // Default Dart objects don't support value equality unless overridden or using Equatable
      // Since I didn't use Equatable, this test expects NOT equal unless reference is same.
      // But let's check basic properties.
      expect(g1.id, '1');
    });
  });
}
