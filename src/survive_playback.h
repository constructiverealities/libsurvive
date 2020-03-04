#include <survive.h>

void survive_destroy_recording(SurviveContext *ctx);
void survive_install_recording(SurviveContext *ctx);
void survive_recording_config_process(SurviveObject *so, char *ct0conf, int len);

void survive_recording_lighthouse_process(SurviveContext *ctx, uint8_t lighthouse, SurvivePose *lh_pose,
										  SurvivePose *obj);
void survive_recording_lightcap(SurviveObject *so, LightcapElement *le);
void survive_recording_raw_pose_process(SurviveObject *so, uint8_t lighthouse, const SurvivePose *pose);
void survive_recording_velocity_process(SurviveObject *so, uint8_t lighthouse, const SurviveVelocity *velocity);
void survive_recording_info_process(SurviveContext *ctx, const char *fault);
void survive_recording_sweep_process(SurviveObject *so, survive_channel channel, int sensor_id,
									 survive_timecode timecode, bool flag);
void survive_recording_angle_process(struct SurviveObject *so, int sensor_id, int acode, uint32_t timecode, FLT length,
									 FLT angle, uint32_t lh);
void survive_recording_sweep_angle_process(SurviveObject *so, survive_channel channel, int sensor_id,
										   survive_timecode timecode, int8_t plane, FLT angle);
void survive_recording_sync_process(SurviveObject *so, survive_channel channel, survive_timecode timecode, bool ootx,
									bool gen);

void survive_recording_external_pose_process(SurviveContext *ctx, const char *name, const SurvivePose *pose);
void survive_recording_external_velocity_process(SurviveContext *ctx, const char *name,
												 const SurviveVelocity *velocity);

void survive_recording_light_process(struct SurviveObject *so, int sensor_id, int acode, int timeinsweep,
									 uint32_t timecode, uint32_t length, uint32_t lh);

void survive_recording_imu_process(struct SurviveObject *so, int mask, FLT *accelgyro, uint32_t timecode, int id);
void survive_recording_raw_imu_process(struct SurviveObject *so, int mask, FLT *accelgyro, uint32_t timecode, int id);
