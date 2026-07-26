import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import {
  ContinuationSnapshot,
  ContinuationSnapshotCodec,
  DistributedChangeEvent,
  DistributedEventCodec,
  DistributedEventType,
  DistributedStudySnapshot,
  DistributedStudySnapshotCodec
} from '../main/ets/model/DistributedStudyModels';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });
    it('distributedSessionIdIsStableAndSafe', 0, () => {
      expect(DistributedStudySnapshotCodec.sessionIdForUser(42))
        .assertEqual('smartstudy_user_42');
      expect(DistributedStudySnapshotCodec.sessionIdForUser(-1))
        .assertEqual('smartstudy_user_0');
    });
    it('distributedSnapshotOnlyKeepsAllowedFields', 0, () => {
      const source = new DistributedStudySnapshot();
      source.routeName = 'AdminPage';
      source.taskId = -10;
      source.taskStatus = '任意状态';
      source.selectedDate = '2026-99-99';
      source.filter = 'UNKNOWN';
      source.updatedAt = 100;
      const normalized: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
      expect(normalized.routeName).assertEqual('');
      expect(normalized.taskId).assertEqual(0);
      expect(normalized.taskStatus).assertEqual('');
      expect(normalized.selectedDate).assertEqual('');
      expect(normalized.filter).assertEqual('WEEK');
    });
    it('distributedSnapshotRejectsOldSchema', 0, () => {
      const source = new DistributedStudySnapshot();
      source.schemaVersion = 0;
      source.routeName = 'StudyPlanPage';
      source.selectedDate = '2026-07-26';
      source.filter = 'TODAY';
      source.updatedAt = 100;
      expect(DistributedStudySnapshotCodec.isUsable(source)).assertFalse();
      const normalized: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
      expect(DistributedStudySnapshotCodec.isUsable(normalized)).assertFalse();
    });
    it('distributedEventKeepsOnlyLightweightFields', 0, () => {
      const source = new DistributedChangeEvent();
      source.schemaVersion = DistributedEventCodec.SCHEMA_VERSION;
      source.eventId = 'device_1_100_1';
      source.eventType = DistributedEventType.WRONG_QUESTION_UPDATED;
      source.entityType = 'WRONG_QUESTION';
      source.entityId = 9;
      source.entityKey = '  safe-key  ';
      source.sourceDeviceId = ' install_abc ';
      source.userId = 42;
      source.updatedAt = 100;
      const normalized: DistributedChangeEvent = DistributedEventCodec.normalize(source);
      expect(normalized.entityKey).assertEqual('safe-key');
      expect(normalized.sourceDeviceId).assertEqual('install_abc');
      expect(DistributedEventCodec.isUsable(normalized)).assertTrue();
    });
    it('continuationRejectsPrivateOrUnknownRoutes', 0, () => {
      const source = new ContinuationSnapshot();
      source.schemaVersion = ContinuationSnapshotCodec.SCHEMA_VERSION;
      source.routeName = 'LoginPage';
      source.searchKeyword = '六年级数学';
      source.updatedAt = 100;
      const normalized: ContinuationSnapshot = ContinuationSnapshotCodec.normalize(source);
      expect(normalized.routeName).assertEqual('');
      expect(ContinuationSnapshotCodec.isUsable(normalized)).assertFalse();
    });
  });
}
