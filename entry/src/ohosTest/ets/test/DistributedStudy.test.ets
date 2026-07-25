import { describe, expect, it } from '@ohos/hypium';
import {
  DistributedStudySnapshot,
  DistributedStudySnapshotCodec
} from '../../../main/ets/model/DistributedStudyModels';

export default function distributedStudyTest() {
  describe('DistributedStudySnapshotCodec', () => {
    it('creates stable account session id', 0, () => {
      expect(DistributedStudySnapshotCodec.sessionIdForUser(42))
        .assertEqual('smartstudy_user_42');
    });

    it('removes fields outside the distributed whitelist', 0, () => {
      const source = new DistributedStudySnapshot();
      source.routeName = 'AdminPage';
      source.taskId = -1;
      source.taskStatus = '未知状态';
      source.selectedDate = 'invalid-date';
      source.filter = 'UNKNOWN';
      source.updatedAt = 100;
      const normalized: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
      expect(normalized.routeName).assertEqual('');
      expect(normalized.taskId).assertEqual(0);
      expect(normalized.taskStatus).assertEqual('');
      expect(normalized.selectedDate).assertEqual('');
      expect(normalized.filter).assertEqual('WEEK');
    });

    it('rejects unsupported snapshot schema', 0, () => {
      const source = new DistributedStudySnapshot();
      source.schemaVersion = 0;
      source.routeName = 'StudyPlanPage';
      source.selectedDate = '2026-07-26';
      source.filter = 'TODAY';
      source.updatedAt = 100;
      expect(DistributedStudySnapshotCodec.isUsable(source)).assertFalse();
    });
  });
}
