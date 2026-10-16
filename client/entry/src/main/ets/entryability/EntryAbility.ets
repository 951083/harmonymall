import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'HarmonyMall', 'EntryAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'HarmonyMall', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/IndexPage', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'HarmonyMall', 'loadContent failed: %{public}s', err.message);
      } else {
        hilog.info(0x0000, 'HarmonyMall', 'loadContent success');
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'HarmonyMall', 'EntryAbility onWindowStageDestroy');
  }
}
