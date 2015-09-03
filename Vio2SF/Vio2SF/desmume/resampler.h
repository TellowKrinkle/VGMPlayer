#ifndef _RESAMPLER_H_
#define _RESAMPLER_H_

#define RESAMPLER_DECORATE TWOSF

#ifdef RESAMPLER_DECORATE
#define PASTE(a,b) a ## b
#define EVALUATE(a,b) PASTE(a,b)
#define TWOSF_resampler_init EVALUATE(RESAMPLER_DECORATE,_resampler_init)
#define TWOSF_resampler_create EVALUATE(RESAMPLER_DECORATE,_resampler_create)
#define TWOSF_resampler_delete EVALUATE(RESAMPLER_DECORATE,_resampler_delete)
#define TWOSF_resampler_dup EVALUATE(RESAMPLER_DECORATE,_resampler_dup)
#define TWOSF_resampler_dup_inplace EVALUATE(RESAMPLER_DECORATE,_resampler_dup_inplace)
#define TWOSF_resampler_set_quality EVALUATE(RESAMPLER_DECORATE,_resampler_set_quality)
#define TWOSF_resampler_get_free_count EVALUATE(RESAMPLER_DECORATE,_resampler_get_free_count)
#define TWOSF_resampler_write_sample EVALUATE(RESAMPLER_DECORATE,_resampler_write_sample)
#define TWOSF_resampler_write_sample_fixed EVALUATE(RESAMPLER_DECORATE,_resampler_write_sample_fixed)
#define TWOSF_resampler_set_rate EVALUATE(RESAMPLER_DECORATE,_resampler_set_rate)
#define TWOSF_resampler_ready EVALUATE(RESAMPLER_DECORATE,_resampler_ready)
#define TWOSF_resampler_clear EVALUATE(RESAMPLER_DECORATE,_resampler_clear)
#define TWOSF_resampler_get_sample_count EVALUATE(RESAMPLER_DECORATE,_resampler_get_sample_count)
#define TWOSF_resampler_get_sample EVALUATE(RESAMPLER_DECORATE,_resampler_get_sample)
#define TWOSF_resampler_get_sample_float EVALUATE(RESAMPLER_DECORATE,_resampler_get_sample_float)
#define TWOSF_resampler_remove_sample EVALUATE(RESAMPLER_DECORATE,_resampler_remove_sample)
#endif

#ifdef __cplusplus
extern "C" {
#endif
    
void TWOSF_resampler_init(void);

void * TWOSF_resampler_create(void);
void TWOSF_resampler_delete(void *);
void * TWOSF_resampler_dup(const void *);
void TWOSF_resampler_dup_inplace(void *, const void *);

enum
{
    TWOSF_RESAMPLER_QUALITY_MIN = 0,
    TWOSF_RESAMPLER_QUALITY_ZOH = 0,
    TWOSF_RESAMPLER_QUALITY_BLEP = 1,
    TWOSF_RESAMPLER_QUALITY_LINEAR = 2,
    TWOSF_RESAMPLER_QUALITY_BLAM = 3,
    TWOSF_RESAMPLER_QUALITY_CUBIC = 4,
    TWOSF_RESAMPLER_QUALITY_SINC = 5,
    TWOSF_RESAMPLER_QUALITY_MAX = 5
};

void TWOSF_resampler_set_quality(void *, int quality);

int TWOSF_resampler_get_free_count(void *);
void TWOSF_resampler_write_sample(void *, short sample);
void TWOSF_resampler_write_sample_fixed(void *, int sample, unsigned char depth);
void TWOSF_resampler_set_rate( void *, double new_factor );
int TWOSF_resampler_ready(void *);
void TWOSF_resampler_clear(void *);
int TWOSF_resampler_get_sample_count(void *);
int TWOSF_resampler_get_sample(void *);
float TWOSF_resampler_get_sample_float(void *);
void TWOSF_resampler_remove_sample(void *, int decay);

#ifdef __cplusplus
}
#endif

#endif
