# New ports collection makefile for:	p5-openxpki-i18n
# Date created:				03 Oct 2006
# Whom:					svysh
#
# $FreeBSD: ports/security/p5-openxpki-i18n/Makefile,v 1.8 2009/01/22 02:46:26 araujo Exp $
#

PORTNAME=	openxpki-i18n
PORTVERSION=	0.9.1395
CATEGORIES=	security perl5
MASTER_SITES=	${MASTER_SITE_SOURCEFORGE}
MASTER_SITE_SUBDIR=	openxpki
PKGNAMEPREFIX=	p5-
DIST_SUBDIR=	openxpki

MAINTAINER=	svysh@pn.sinp.msu.ru
COMMENT=	Perl based trustcenter software for PKI: i18n tools

BUILD_DEPENDS=	\
	${SITE_PERL}/${PERL_ARCH}/OpenXPKI.pm:${PORTSDIR}/security/p5-openxpki
RUN_DEPENDS=	${BUILD_DEPENDS}

USE_PERL5=	yes
USE_GETTEXT=	yes
### We can not go WITHOUT_NLS. Internationalization is needed
### even to use English language.
USE_GMAKE=	yes
ALL_TARGET=	default

.include <bsd.port.mk>
