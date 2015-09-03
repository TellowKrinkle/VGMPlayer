#ifndef _RESAMPLER_H_
#define _RESAMPLER_H_

#define RESAMPLER_DECORATE USF

#ifdef RESAMPLER_DECORATE
#define PASTE(a,b) a ## b
#define EVALUATE(a,b) PASTE(a,b)
#define USF_resampler_create EVALUATE(RESAMPLER_DECORATE,_resampler_create)
#define USF_resampler_delete EVALUATE(RESAMPLER_DECORATE,_resampler_delete)
#define USF_resampler_dup EVALUATE(RESAMPLER_DECORATE,_resampler_dup)
#define USF_resampler_dup_inplace EVALUATE(RESAMPLER_DECORATE,_resampler_dup_inplace)
#define USF_resampler_set_quality EVALUATE(RESAMPLER_DECORATE,_resampler_set_quality)
#define USF_resampler_get_free_count EVALUATE(RESAMPLER_DECORATE,_resampler_get_free_count)
#define USF_resampler_write_sample EVALUATE(RESAMPLER_DECORATE,_resampler_write_sample)
#define USF_resampler_write_sample_fixed EVALUATE(RESAMPLER_DECORATE,_resampler_write_sample_fixed)
#define USF_resampler_set_rate EVALUATE(RESAMPLER_DECORATE,_resampler_set_rate)
#define USF_resampler_ready EVALUATE(RESAMPLER_DECORATE,_resampler_ready)
#define USF_resampler_clear EVALUATE(RESAMPLER_DECORATE,_resampler_clear)
#define USF_resampler_get_sample_count EVALUATE(RESAMPLER_DECORATE,_resampler_get_sample_count)
#define USF_resampler_get_sample EVALUATE(RESAMPLER_DECORATE,_resampler_get_sample)
#define USF_resampler_get_sample_float EVALUATE(RESAMPLER_DECORATE,_resampler_get_sample_float)
#define USF_resampler_remove_sample EVALUATE(RESAMPLER_DECORATE,_resampler_remove_sample)
#endif

void * USF_resampler_create(void);
void USF_resampler_delete(void *);
void * USF_resampler_dup(const void *);
void USF_resampler_dup_inplace(void *, const void *);

int USF_resampler_get_free_count(void *);
void USF_resampler_write_sample(void *, short sample_l, short sample_r);
void USF_resampler_set_rate( void *, double new_factor );
int USF_resampler_ready(void *);
void USF_resampler_clear(void *);
int USF_resampler_get_sample_count(void *);
void USF_resampler_get_sample(void *, short * sample_l, short * sample_r);
void USF_resampler_remove_sample(void *);

#endif
